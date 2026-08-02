#include "ldfs.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/stat.h>
#include <sys/vnode.h>
#include <unistd.h>

#define LDFS_BUFFER_SIZE (128 * 1024)
#define LDFS_DEFAULT_WORKERS 5
#define LDFS_PARTIAL_INTERVAL 96

typedef struct {
    char *path;
} ldfs_path_item;

typedef struct {
    ldfs_path_item *items;
    size_t count;
    size_t capacity;
    pthread_mutex_t lock;
} ldfs_path_stack;

typedef struct {
    uint64_t *values;
    size_t capacity;
    pthread_mutex_t lock;
} ldfs_inode_set;

typedef struct {
    const ldfs_scan_options *options;
    int64_t *child_sizes;
    dev_t root_dev;
    atomic_int_least64_t total_size;
    atomic_int_least64_t files_scanned;
    ldfs_path_stack stack;
    ldfs_inode_set seen_inodes;
    pthread_mutex_t child_lock;
    ldfs_progress_fn progress;
    void *progress_ctx;
    int64_t last_progress_files;
    pthread_mutex_t progress_lock;
} ldfs_scan_context;

static bool ldfs_is_cancelled(const ldfs_scan_context *ctx) {
    if (!ctx->options->should_cancel) {
        return false;
    }
    return ctx->options->should_cancel(ctx->options->cancel_ctx);
}

static int ldfs_path_stack_push(ldfs_path_stack *stack, const char *path) {
    pthread_mutex_lock(&stack->lock);
    if (stack->count >= stack->capacity) {
        size_t new_cap = stack->capacity == 0 ? 64 : stack->capacity * 2;
        ldfs_path_item *new_items = realloc(stack->items, new_cap * sizeof(ldfs_path_item));
        if (!new_items) {
            pthread_mutex_unlock(&stack->lock);
            return -1;
        }
        stack->items = new_items;
        stack->capacity = new_cap;
    }
    char *copy = strdup(path);
    if (!copy) {
        pthread_mutex_unlock(&stack->lock);
        return -1;
    }
    stack->items[stack->count].path = copy;
    stack->count += 1;
    pthread_mutex_unlock(&stack->lock);
    return 0;
}

static char *ldfs_path_stack_pop(ldfs_path_stack *stack) {
    pthread_mutex_lock(&stack->lock);
    if (stack->count == 0) {
        pthread_mutex_unlock(&stack->lock);
        return NULL;
    }
    size_t index = stack->count - 1;
    char *path = stack->items[index].path;
    stack->items[index].path = NULL;
    stack->count -= 1;
    pthread_mutex_unlock(&stack->lock);
    return path;
}

static void ldfs_path_stack_free(ldfs_path_stack *stack) {
    for (size_t i = 0; i < stack->count; i++) {
        free(stack->items[i].path);
    }
    free(stack->items);
    pthread_mutex_destroy(&stack->lock);
}

static size_t ldfs_path_stack_count(ldfs_path_stack *stack) {
    pthread_mutex_lock(&stack->lock);
    size_t count = stack->count;
    pthread_mutex_unlock(&stack->lock);
    return count;
}

static bool ldfs_inode_seen(ldfs_inode_set *set, uint64_t inode) {
    if (inode == 0) {
        return false;
    }
    pthread_mutex_lock(&set->lock);
    for (size_t i = 0; i < set->capacity; i++) {
        if (set->values[i] == inode) {
            pthread_mutex_unlock(&set->lock);
            return true;
        }
        if (set->values[i] == 0) {
            set->values[i] = inode;
            pthread_mutex_unlock(&set->lock);
            return false;
        }
    }
    pthread_mutex_unlock(&set->lock);
    return false;
}

static void ldfs_inode_set_free(ldfs_inode_set *set) {
    free(set->values);
    pthread_mutex_destroy(&set->lock);
}

static int ldfs_match_child_index(const ldfs_scan_context *ctx, const char *file_path) {
    for (size_t i = 0; i < ctx->options->child_count; i++) {
        const ldfs_child_entry *child = &ctx->options->children[i];
        for (size_t p = 0; p < child->prefix_count; p++) {
            const char *prefix = child->prefixes[p];
            if (!prefix) {
                continue;
            }
            size_t len = strlen(prefix);
            if (strncmp(file_path, prefix, len) != 0) {
                continue;
            }
            if (file_path[len] == '/' || file_path[len] == '\0') {
                return (int)i;
            }
        }
    }
    return -1;
}

static void ldfs_add_file(
    ldfs_scan_context *ctx,
    const char *file_path,
    int64_t allocated,
    uint64_t inode
) {
    if (allocated <= 0) {
        return;
    }
    if (ldfs_inode_seen(&ctx->seen_inodes, inode)) {
        return;
    }

    atomic_fetch_add_explicit(&ctx->total_size, allocated, memory_order_relaxed);
    atomic_fetch_add_explicit(&ctx->files_scanned, 1, memory_order_relaxed);

    int child_index = ldfs_match_child_index(ctx, file_path);
    if (child_index >= 0) {
        pthread_mutex_lock(&ctx->child_lock);
        ctx->child_sizes[child_index] += allocated;
        pthread_mutex_unlock(&ctx->child_lock);
    }
}

static void ldfs_maybe_publish_progress(ldfs_scan_context *ctx) {
    if (!ctx->progress) {
        return;
    }
    int64_t files = atomic_load_explicit(&ctx->files_scanned, memory_order_relaxed);
  if (files - ctx->last_progress_files < LDFS_PARTIAL_INTERVAL) {
        return;
    }
    pthread_mutex_lock(&ctx->progress_lock);
    if (files - ctx->last_progress_files < LDFS_PARTIAL_INTERVAL) {
        pthread_mutex_unlock(&ctx->progress_lock);
        return;
    }
    ctx->last_progress_files = files;
    int64_t total = atomic_load_explicit(&ctx->total_size, memory_order_relaxed);
    ctx->progress(
        ctx->progress_ctx,
        ctx->child_sizes,
        ctx->options->child_count,
        total,
        files
    );
    pthread_mutex_unlock(&ctx->progress_lock);
}

static bool ldfs_is_hidden_name(const char *name) {
    return name[0] == '.';
}

static int ldfs_scan_directory(ldfs_scan_context *ctx, const char *dir_path) {
    if (ldfs_is_cancelled(ctx)) {
        return 0;
    }

    int dirfd = open(dir_path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (dirfd < 0) {
        return 0;
    }

    struct attrlist attr_list;
    memset(&attr_list, 0, sizeof(attr_list));
    attr_list.bitmapcount = ATTR_BIT_MAP_COUNT;
    attr_list.commonattr =
        ATTR_CMN_RETURNED_ATTRS |
        ATTR_CMN_ERROR |
        ATTR_CMN_NAME |
        ATTR_CMN_OBJTYPE |
        ATTR_CMN_FILEID |
        ATTR_CMN_FLAGS;
    attr_list.fileattr = ATTR_FILE_DATALENGTH | ATTR_FILE_DATAALLOCSIZE;

    char buffer[LDFS_BUFFER_SIZE];

    for (;;) {
        if (ldfs_is_cancelled(ctx)) {
            break;
        }

        int retcount = getattrlistbulk(dirfd, &attr_list, buffer, sizeof(buffer), 0);
        if (retcount < 0) {
            break;
        }
        if (retcount == 0) {
            break;
        }

        char *cursor = buffer;
        for (int index = 0; index < retcount; index++) {
            char *field = cursor;
            attribute_set_t returned;
            memcpy(&returned, field, sizeof(returned));
            field += sizeof(returned);

            uint32_t error = 0;
            if (returned.commonattr & ATTR_CMN_ERROR) {
                memcpy(&error, field, sizeof(error));
                field += sizeof(error);
            }

            char name[NAME_MAX + 1] = {0};
            if (returned.commonattr & ATTR_CMN_NAME) {
                uint32_t name_length = 0;
                memcpy(&name_length, field, sizeof(name_length));
                field += sizeof(name_length);
                if (name_length > 0 && name_length <= NAME_MAX) {
                    memcpy(name, field, name_length);
                    name[name_length] = '\0';
                    field += name_length;
                }
            }

            fsobj_type_t obj_type = 0;
            if (returned.commonattr & ATTR_CMN_OBJTYPE) {
                memcpy(&obj_type, field, sizeof(obj_type));
                field += sizeof(obj_type);
            }

            uint64_t file_id = 0;
            if (returned.commonattr & ATTR_CMN_FILEID) {
                memcpy(&file_id, field, sizeof(file_id));
                field += sizeof(file_id);
            }

            if (returned.commonattr & ATTR_CMN_FLAGS) {
                field += sizeof(uint32_t);
            }

            off_t data_length = 0;
            if (returned.fileattr & ATTR_FILE_DATALENGTH) {
                memcpy(&data_length, field, sizeof(data_length));
                field += sizeof(data_length);
            }

            off_t alloc_size = 0;
            if (returned.fileattr & ATTR_FILE_DATAALLOCSIZE) {
                memcpy(&alloc_size, field, sizeof(alloc_size));
                field += sizeof(alloc_size);
            }

            cursor = field;

            if (error != 0) {
                continue;
            }
            if (name[0] == '\0') {
                continue;
            }
            if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
                continue;
            }
            if (ctx->options->skip_hidden && ldfs_is_hidden_name(name)) {
                continue;
            }

            char child_path[PATH_MAX];
            size_t dir_len = strlen(dir_path);
            if (dir_len + 1 + strlen(name) + 1 > PATH_MAX) {
                continue;
            }
            snprintf(child_path, sizeof(child_path), "%s/%s", dir_path, name);

            if (obj_type == VDIR) {
                struct stat dir_stat;
                if (stat(child_path, &dir_stat) == 0 && dir_stat.st_dev != ctx->root_dev) {
                    continue;
                }
                ldfs_path_stack_push(&ctx->stack, child_path);
                continue;
            }

            if (obj_type == VREG) {
                int64_t size = alloc_size > 0 ? (int64_t)alloc_size : (int64_t)data_length;
                ldfs_add_file(ctx, child_path, size, file_id);
                ldfs_maybe_publish_progress(ctx);
            }
        }
    }

    close(dirfd);
    return 0;
}

static void ldfs_worker_loop(ldfs_scan_context *ctx) {
    for (;;) {
        char *path = ldfs_path_stack_pop(&ctx->stack);
        if (!path) {
            if (ldfs_path_stack_count(&ctx->stack) == 0) {
                break;
            }
            usleep(1000);
            continue;
        }
        ldfs_scan_directory(ctx, path);
        free(path);
    }
}

static void *ldfs_worker_thread(void *arg) {
    ldfs_worker_loop((ldfs_scan_context *)arg);
    return NULL;
}

int ldfs_scan_immediate_children(
    const ldfs_scan_options *options,
    int64_t *child_sizes_out,
    int64_t *total_size_out,
    int64_t *files_scanned_out,
    ldfs_progress_fn progress,
    void *progress_ctx
) {
    if (!options || !options->root_path || !child_sizes_out || !total_size_out || !files_scanned_out) {
        return -EINVAL;
    }

    memset(child_sizes_out, 0, options->child_count * sizeof(int64_t));

    ldfs_scan_context ctx = {
        .options = options,
        .child_sizes = child_sizes_out,
        .progress = progress,
        .progress_ctx = progress_ctx,
        .last_progress_files = 0,
    };
    atomic_init(&ctx.total_size, 0);
    atomic_init(&ctx.files_scanned, 0);

    pthread_mutex_init(&ctx.stack.lock, NULL);
    pthread_mutex_init(&ctx.seen_inodes.lock, NULL);
    pthread_mutex_init(&ctx.child_lock, NULL);
    pthread_mutex_init(&ctx.progress_lock, NULL);

    ctx.seen_inodes.capacity = 8192;
    ctx.seen_inodes.values = calloc(ctx.seen_inodes.capacity, sizeof(uint64_t));

    if (!ctx.seen_inodes.values) {
        return -ENOMEM;
    }

    struct stat root_stat;
    if (stat(options->root_path, &root_stat) == 0) {
        ctx.root_dev = root_stat.st_dev;
    } else {
        ctx.root_dev = 0;
    }

    if (ldfs_path_stack_push(&ctx.stack, options->root_path) != 0) {
        ldfs_inode_set_free(&ctx.seen_inodes);
        return -ENOMEM;
    }

    int worker_count = options->worker_count > 0 ? options->worker_count : LDFS_DEFAULT_WORKERS;
    if (worker_count > 8) {
        worker_count = 8;
    }

    pthread_t workers[8];
    int launched = 0;
    for (int i = 0; i < worker_count; i++) {
        if (pthread_create(&workers[i], NULL, ldfs_worker_thread, &ctx) == 0) {
            launched += 1;
        }
    }

    if (launched == 0) {
        ldfs_worker_loop(&ctx);
    } else {
        for (int i = 0; i < launched; i++) {
            pthread_join(workers[i], NULL);
        }
    }

    if (progress) {
        int64_t files = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);
        int64_t total = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
        progress(progress_ctx, child_sizes_out, options->child_count, total, files);
    }

    *total_size_out = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
    *files_scanned_out = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);

    ldfs_path_stack_free(&ctx.stack);
    ldfs_inode_set_free(&ctx.seen_inodes);
    pthread_mutex_destroy(&ctx.child_lock);
    pthread_mutex_destroy(&ctx.progress_lock);

    return 0;
}
