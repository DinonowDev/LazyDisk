#include "ldfs_internal.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/attr.h>
#include <sys/stat.h>
#include <sys/vnode.h>
#include <unistd.h>

static uint64_t ldfs_hash_string(const char *s) {
    uint64_t hash = 5381;
    while (*s) {
        hash = ((hash << 5) + hash) + (unsigned char)*s;
        s++;
    }
    return hash;
}

static ldfs_path_stat_node *ldfs_path_stats_find_locked(
    ldfs_path_stats *stats,
    const char *path,
    bool create
) {
    size_t bucket = (size_t)(ldfs_hash_string(path) % stats->bucket_count);
    size_t idx = stats->bucket_heads[bucket];

    while (idx != LDFS_NO_INDEX) {
        if (strcmp(stats->nodes[idx].path, path) == 0) {
            return &stats->nodes[idx];
        }
        idx = stats->nodes[idx].next_in_bucket;
    }

    if (!create) {
        return NULL;
    }

    if (stats->count >= stats->capacity) {
        size_t new_cap = stats->capacity == 0 ? 256 : stats->capacity * 2;
        ldfs_path_stat_node *new_nodes = realloc(stats->nodes, new_cap * sizeof(ldfs_path_stat_node));
        if (!new_nodes) {
            return NULL;
        }
        stats->nodes = new_nodes;
        stats->capacity = new_cap;
    }

    size_t new_idx = stats->count;
    ldfs_path_stat_node *slot = &stats->nodes[new_idx];
    slot->path = strdup(path);
    if (!slot->path) {
        return NULL;
    }
    slot->size = 0;
    slot->file_count = 0;
    slot->is_directory = 0;
    slot->next_in_bucket = stats->bucket_heads[bucket];
    stats->bucket_heads[bucket] = new_idx;
    stats->count += 1;
    return slot;
}

size_t ldfs_effective_buffer_size(size_t requested) {
    if (requested >= LDFS_TURBO_BUFFER) {
        return LDFS_TURBO_BUFFER;
    }
    if (requested > 0) {
        return requested;
    }
    return LDFS_DEFAULT_BUFFER;
}

int ldfs_effective_worker_count(int requested, bool turbo) {
    int count = requested > 0 ? requested : (turbo ? LDFS_TURBO_WORKERS : LDFS_DEFAULT_WORKERS);
    if (turbo && count < LDFS_TURBO_WORKERS) {
        count = LDFS_TURBO_WORKERS;
    }
    if (count > LDFS_MAX_WORKERS) {
        count = LDFS_MAX_WORKERS;
    }
    if (count < 1) {
        count = 1;
    }
    return count;
}

void ldfs_work_queue_init(ldfs_work_queue *queue) {
    queue->items = NULL;
    queue->head = 0;
    queue->tail = 0;
    queue->capacity = 0;
    queue->inflight = 0;
    queue->closed = 0;
    pthread_mutex_init(&queue->lock, NULL);
    pthread_cond_init(&queue->cond, NULL);
}

void ldfs_work_queue_free(ldfs_work_queue *queue) {
    if (queue->items) {
        for (size_t i = queue->head; i < queue->tail; i++) {
            free(queue->items[i].path);
            if (queue->items[i].dirfd >= 0) {
                close(queue->items[i].dirfd);
            }
        }
    }
    free(queue->items);
    pthread_mutex_destroy(&queue->lock);
    pthread_cond_destroy(&queue->cond);
}

static int ldfs_work_queue_grow(ldfs_work_queue *queue) {
    size_t new_cap = queue->capacity == 0 ? 128 : queue->capacity * 2;
    ldfs_queue_item *new_items = calloc(new_cap, sizeof(ldfs_queue_item));
    if (!new_items) {
        return -1;
    }
    size_t used = queue->tail - queue->head;
    if (queue->items && queue->capacity > 0) {
        for (size_t i = 0; i < used; i++) {
            new_items[i] = queue->items[queue->head + i];
        }
    }
    free(queue->items);
    queue->items = new_items;
    queue->head = 0;
    queue->tail = used;
    queue->capacity = new_cap;
    return 0;
}

int ldfs_work_queue_push_fd(ldfs_work_queue *queue, const char *path, int dirfd) {
    pthread_mutex_lock(&queue->lock);
    if (queue->tail - queue->head >= queue->capacity) {
        if (ldfs_work_queue_grow(queue) != 0) {
            pthread_mutex_unlock(&queue->lock);
            return -1;
        }
    }
    char *copy = strdup(path);
    if (!copy) {
        pthread_mutex_unlock(&queue->lock);
        return -1;
    }
    queue->items[queue->tail].path = copy;
    queue->items[queue->tail].dirfd = dirfd;
    queue->tail += 1;
    pthread_cond_signal(&queue->cond);
    pthread_mutex_unlock(&queue->lock);
    return 0;
}

ldfs_queue_item ldfs_work_queue_pop_wait(ldfs_work_queue *queue) {
    ldfs_queue_item empty = {NULL, -1};
    pthread_mutex_lock(&queue->lock);
    while (queue->head >= queue->tail) {
        if (queue->closed) {
            pthread_mutex_unlock(&queue->lock);
            return empty;
        }
        pthread_cond_wait(&queue->cond, &queue->lock);
    }
    ldfs_queue_item item = queue->items[queue->head];
    queue->items[queue->head].path = NULL;
    queue->items[queue->head].dirfd = -1;
    queue->head += 1;
    if (queue->head == queue->tail) {
        queue->head = 0;
        queue->tail = 0;
    }
    queue->inflight += 1;
    pthread_mutex_unlock(&queue->lock);
    return item;
}

void ldfs_work_queue_finish_item(ldfs_work_queue *queue) {
    pthread_mutex_lock(&queue->lock);
    if (queue->inflight > 0) {
        queue->inflight -= 1;
    }
    if (queue->head >= queue->tail && queue->inflight == 0) {
        queue->closed = 1;
        pthread_cond_broadcast(&queue->cond);
    } else if (queue->head < queue->tail) {
        pthread_cond_signal(&queue->cond);
    }
    pthread_mutex_unlock(&queue->lock);
}

size_t ldfs_work_queue_size(ldfs_work_queue *queue) {
    pthread_mutex_lock(&queue->lock);
    size_t size = queue->tail - queue->head;
    pthread_mutex_unlock(&queue->lock);
    return size;
}

ldfs_inode_hash *ldfs_inode_hash_create(void) {
    ldfs_inode_hash *hash = calloc(1, sizeof(ldfs_inode_hash));
    if (!hash) {
        return NULL;
    }
    hash->buckets = calloc(LDFS_INODE_BUCKETS, sizeof(uint64_t));
    if (!hash->buckets) {
        free(hash);
        return NULL;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_init(&hash->locks[i], NULL);
    }
    return hash;
}

void ldfs_inode_hash_free(ldfs_inode_hash *hash) {
    if (!hash) {
        return;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_destroy(&hash->locks[i]);
    }
    free(hash->buckets);
    free(hash);
}

bool ldfs_inode_hash_seen(ldfs_inode_hash *hash, uint64_t inode) {
    if (!hash || inode == 0) {
        return false;
    }
    size_t bucket = (inode >> 8) % LDFS_INODE_BUCKETS;
    pthread_mutex_lock(&hash->locks[bucket]);
    if (hash->buckets[bucket] == inode) {
        pthread_mutex_unlock(&hash->locks[bucket]);
        return true;
    }
    hash->buckets[bucket] = inode;
    pthread_mutex_unlock(&hash->locks[bucket]);
    return false;
}

ldfs_path_stats *ldfs_path_stats_create(void) {
    ldfs_path_stats *stats = calloc(1, sizeof(ldfs_path_stats));
    if (!stats) {
        return NULL;
    }
    stats->bucket_count = LDFS_PATH_BUCKETS;
    stats->bucket_heads = malloc(stats->bucket_count * sizeof(size_t));
    if (!stats->bucket_heads) {
        free(stats);
        return NULL;
    }
    for (size_t i = 0; i < stats->bucket_count; i++) {
        stats->bucket_heads[i] = LDFS_NO_INDEX;
    }
    pthread_mutex_init(&stats->lock, NULL);
    return stats;
}

void ldfs_path_stats_free(ldfs_path_stats *stats) {
    if (!stats) {
        return;
    }
    for (size_t i = 0; i < stats->count; i++) {
        free(stats->nodes[i].path);
    }
    free(stats->nodes);
    free(stats->bucket_heads);
    pthread_mutex_destroy(&stats->lock);
    free(stats);
}

void ldfs_path_stats_mark_directory(ldfs_path_stats *stats, const char *path) {
    pthread_mutex_lock(&stats->lock);
    ldfs_path_stat_node *node = ldfs_path_stats_find_locked(stats, path, true);
    if (node) {
        node->is_directory = 1;
    }
    pthread_mutex_unlock(&stats->lock);
}

void ldfs_path_stats_add_size(ldfs_path_stats *stats, const char *path, int64_t size) {
    if (size <= 0) {
        return;
    }
    pthread_mutex_lock(&stats->lock);
    ldfs_path_stat_node *node = ldfs_path_stats_find_locked(stats, path, true);
    if (node) {
        node->size += size;
    }
    pthread_mutex_unlock(&stats->lock);
}

void ldfs_path_stats_add_file(ldfs_path_stats *stats, const char *parent_path, int64_t size) {
    if (size <= 0) {
        return;
    }
    pthread_mutex_lock(&stats->lock);
    ldfs_path_stat_node *node = ldfs_path_stats_find_locked(stats, parent_path, true);
    if (node) {
        node->size += size;
        node->file_count += 1;
    }
    pthread_mutex_unlock(&stats->lock);
}

size_t ldfs_path_stats_export(ldfs_path_stats *stats, ldfs_path_stat **out) {
    if (!stats || !out) {
        return 0;
    }
    pthread_mutex_lock(&stats->lock);
    size_t count = stats->count;
    ldfs_path_stat *entries = calloc(count, sizeof(ldfs_path_stat));
    if (!entries) {
        pthread_mutex_unlock(&stats->lock);
        return 0;
    }
    for (size_t i = 0; i < count; i++) {
        entries[i].path = stats->nodes[i].path;
        entries[i].size = stats->nodes[i].size;
        entries[i].file_count = stats->nodes[i].file_count;
        entries[i].is_directory = stats->nodes[i].is_directory;
        stats->nodes[i].path = NULL;
    }
    stats->count = 0;
    for (size_t i = 0; i < stats->bucket_count; i++) {
        stats->bucket_heads[i] = LDFS_NO_INDEX;
    }
    pthread_mutex_unlock(&stats->lock);
    *out = entries;
    return count;
}

size_t ldfs_path_stats_snapshot(ldfs_path_stats *stats, ldfs_path_stat **out) {
    if (!stats || !out) {
        return 0;
    }
    pthread_mutex_lock(&stats->lock);
    size_t count = stats->count;
    ldfs_path_stat *entries = calloc(count, sizeof(ldfs_path_stat));
    if (!entries) {
        pthread_mutex_unlock(&stats->lock);
        return 0;
    }
    for (size_t i = 0; i < count; i++) {
        entries[i].path = strdup(stats->nodes[i].path);
        if (!entries[i].path) {
            for (size_t j = 0; j < i; j++) {
                free((void *)entries[j].path);
            }
            free(entries);
            pthread_mutex_unlock(&stats->lock);
            return 0;
        }
        entries[i].size = stats->nodes[i].size;
        entries[i].file_count = stats->nodes[i].file_count;
        entries[i].is_directory = stats->nodes[i].is_directory;
    }
    pthread_mutex_unlock(&stats->lock);
    *out = entries;
    return count;
}

int ldfs_match_child_index(const ldfs_child_entry *children, size_t child_count, const char *file_path) {
    for (size_t i = 0; i < child_count; i++) {
        const ldfs_child_entry *child = &children[i];
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

static bool ldfs_is_cancelled(ldfs_walk_context *ctx) {
    if (!ctx->options || !ctx->options->should_cancel) {
        return false;
    }
    return ctx->options->should_cancel(ctx->options->cancel_ctx);
}

static void ldfs_tree_accumulate_paths(ldfs_walk_context *ctx, const char *file_path, int64_t size) {
    if (!ctx->stats || ctx->max_depth == 0) {
        return;
    }

    const char *root = ctx->options->root_path;
    size_t root_len = ctx->root_len;
    if (strncmp(file_path, root, root_len) != 0) {
        return;
    }
    const char *relative = file_path + root_len;
    if (*relative == '/') {
        relative++;
    }
    if (*relative == '\0') {
        return;
    }

    char accum[PATH_MAX];
    if (snprintf(accum, sizeof(accum), "%s", root) >= (int)sizeof(accum)) {
        return;
    }

    const char *cursor = relative;
    size_t depth = 0;
    while (*cursor) {
        const char *slash = strchr(cursor, '/');
        size_t part_len = slash ? (size_t)(slash - cursor) : strlen(cursor);
        if (part_len == 0) {
            break;
        }

        size_t accum_len = strlen(accum);
        if (accum_len + 1 + part_len + 1 > sizeof(accum)) {
            break;
        }
        accum[accum_len] = '/';
        memcpy(accum + accum_len + 1, cursor, part_len);
        accum[accum_len + 1 + part_len] = '\0';

        if (!slash) {
            char parent[PATH_MAX];
            strncpy(parent, file_path, sizeof(parent) - 1);
            parent[sizeof(parent) - 1] = '\0';
            char *last_slash = strrchr(parent, '/');
            if (last_slash && last_slash != parent) {
                *last_slash = '\0';
                ldfs_path_stats_add_file(ctx->stats, parent, size);
            }
            break;
        }

        ldfs_path_stats_add_size(ctx->stats, accum, size);
        depth += 1;
        if (depth >= ctx->max_depth) {
            break;
        }
        cursor = slash + 1;
    }
}

static void ldfs_add_file(ldfs_walk_context *ctx, const char *file_path, int64_t allocated, uint64_t inode) {
    if (allocated <= 0) {
        return;
    }
    if (ldfs_inode_hash_seen(ctx->inodes, inode)) {
        return;
    }

    atomic_fetch_add_explicit(&ctx->total_size, allocated, memory_order_relaxed);
    atomic_fetch_add_explicit(&ctx->files_scanned, 1, memory_order_relaxed);

    if (ctx->options->children && ctx->child_sizes) {
        int child_index = ldfs_match_child_index(
            ctx->options->children,
            ctx->options->child_count,
            file_path
        );
        if (child_index >= 0) {
            pthread_mutex_lock(&ctx->child_lock);
            ctx->child_sizes[child_index] += allocated;
            pthread_mutex_unlock(&ctx->child_lock);
        }
    }

    ldfs_tree_accumulate_paths(ctx, file_path, allocated);
}

static void ldfs_maybe_publish(ldfs_walk_context *ctx) {
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
    if (ctx->child_progress && ctx->child_sizes) {
        ctx->child_progress(
            ctx->progress_ctx,
            ctx->child_sizes,
            ctx->options->child_count,
            total,
            files
        );
    } else if (ctx->tree_progress) {
        ldfs_path_stat *snapshot = NULL;
        size_t snapshot_count = 0;
        if (ctx->stats) {
            snapshot_count = ldfs_path_stats_snapshot(ctx->stats, &snapshot);
        }
        ctx->tree_progress(ctx->progress_ctx, files, total, snapshot, snapshot_count);
        ldfs_free_path_stats(snapshot, snapshot_count);
    }
    pthread_mutex_unlock(&ctx->progress_lock);
}

static bool ldfs_is_hidden_name(const char *name) {
    return name[0] == '.';
}

void ldfs_scan_directory_fd(ldfs_walk_context *ctx, const char *dir_path, int dirfd) {
    if (ldfs_is_cancelled(ctx)) {
        if (dirfd >= 0) {
            close(dirfd);
        }
        return;
    }

    int owned_fd = dirfd;
    if (owned_fd < 0) {
        owned_fd = open(dir_path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if (owned_fd < 0) {
            return;
        }
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
        ATTR_CMN_FLAGS |
        ATTR_CMN_DEVID;
    attr_list.fileattr = ATTR_FILE_DATALENGTH | ATTR_FILE_DATAALLOCSIZE;

    size_t buffer_size = ldfs_effective_buffer_size(ctx->buffer_size);
    char *buffer = malloc(buffer_size);
    if (!buffer) {
        close(owned_fd);
        return;
    }

    size_t dir_len = strlen(dir_path);

    for (;;) {
        if (ldfs_is_cancelled(ctx)) {
            break;
        }

        int retcount = getattrlistbulk(owned_fd, &attr_list, buffer, buffer_size, 0);
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

            uint32_t flags = 0;
            if (returned.commonattr & ATTR_CMN_FLAGS) {
                memcpy(&flags, field, sizeof(flags));
                field += sizeof(flags);
            }

            uint32_t dev = 0;
            if (returned.commonattr & ATTR_CMN_DEVID) {
                memcpy(&dev, field, sizeof(dev));
                field += sizeof(dev);
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

            if (error != 0 || name[0] == '\0') {
                continue;
            }
            if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
                continue;
            }
            if (ctx->options->skip_hidden && ldfs_is_hidden_name(name)) {
                continue;
            }

            size_t name_len = strlen(name);
            if (dir_len + 1 + name_len + 1 > PATH_MAX) {
                continue;
            }

            char child_path[PATH_MAX];
            memcpy(child_path, dir_path, dir_len);
            child_path[dir_len] = '/';
            memcpy(child_path + dir_len + 1, name, name_len + 1);

            if (obj_type == VDIR) {
                if (dev != 0 && dev != (uint32_t)ctx->root_dev) {
                    continue;
                }
                int subfd = openat(owned_fd, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
                if (subfd < 0) {
                    continue;
                }
                if (ctx->stats) {
                    ldfs_path_stats_mark_directory(ctx->stats, child_path);
                }
                if (ldfs_work_queue_push_fd(ctx->queue, child_path, subfd) != 0) {
                    close(subfd);
                }
                continue;
            }

            if (obj_type == VREG) {
                int64_t size = alloc_size > 0 ? (int64_t)alloc_size : (int64_t)data_length;
                ldfs_add_file(ctx, child_path, size, file_id);
                ldfs_maybe_publish(ctx);
            }
        }
    }

    free(buffer);
    close(owned_fd);
}

static void *ldfs_worker_thread(void *arg) {
    ldfs_worker_loop((ldfs_walk_context *)arg);
    return NULL;
}

void ldfs_worker_loop(ldfs_walk_context *ctx) {
    for (;;) {
        ldfs_queue_item item = ldfs_work_queue_pop_wait(ctx->queue);
        if (!item.path) {
            break;
        }
        ldfs_scan_directory_fd(ctx, item.path, item.dirfd);
        free(item.path);
        ldfs_work_queue_finish_item(ctx->queue);
    }
}

void ldfs_run_workers(ldfs_walk_context *ctx, int worker_count, void (*worker_fn)(ldfs_walk_context *)) {
    (void)worker_fn;
    pthread_t workers[LDFS_MAX_WORKERS];
    int launched = 0;
    for (int i = 0; i < worker_count; i++) {
        if (pthread_create(&workers[i], NULL, ldfs_worker_thread, ctx) == 0) {
            launched += 1;
        }
    }
    if (launched == 0) {
        ldfs_worker_loop(ctx);
    } else {
        for (int i = 0; i < launched; i++) {
            pthread_join(workers[i], NULL);
        }
    }
}
