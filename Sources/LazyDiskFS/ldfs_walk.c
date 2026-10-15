#include "ldfs_internal.h"
#include "ldfs_bulk.h"
#include "ldfs_clone_key.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <pthread.h>
#include <stdatomic.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/vnode.h>
#include <unistd.h>

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
    ldfs_path_stats_add_ancestor_sizes(ctx->stats, root, root_len, relative, ctx->max_depth, size);
}

static void ldfs_add_file(
    ldfs_walk_context *ctx,
    const char *file_path,
    int64_t allocated,
    uint32_t dev,
    uint64_t inode,
    uint64_t clone_id,
    uint32_t clone_refcnt,
    uint64_t link_id,
    uint64_t parent_ino,
    uint64_t apfs_file_id,
    const struct stat *file_stat
) {
    if (allocated <= 0) {
        return;
    }

    struct stat local_stat;
    if (!file_stat) {
        if (stat(file_path, &local_stat) == 0) {
            file_stat = &local_stat;
        }
    }

    uint32_t identity_dev = dev != 0 ? dev : (uint32_t)ctx->root_dev;
    if (ldfs_inode_hash_seen(ctx->inodes, identity_dev, inode)) {
        atomic_fetch_add_explicit(&ctx->hardlink_files_skipped, 1, memory_order_relaxed);
        return;
    }

    uint64_t dedup_key = ldfs_clone_primary_key(clone_id, link_id);
    if (dedup_key == 0 && file_stat) {
        dedup_key = ldfs_clone_fallback_key(file_path, file_stat, parent_ino, apfs_file_id);
    }
    int64_t ledger_unit = allocated;
    if (file_stat) {
        ledger_unit = (int64_t)file_stat->st_blocks * 512;
        if (ledger_unit <= 0) {
            ledger_unit = (int64_t)file_stat->st_size;
        }
    }

    if (dedup_key != 0 && ctx->clones && ldfs_clone_hash_seen(ctx->clones, dedup_key)) {
        if (ctx->clone_ledger) {
            ldfs_clone_ledger_record(
                ctx->clone_ledger,
                dedup_key,
                file_path,
                file_stat,
                clone_id,
                link_id,
                ledger_unit,
                clone_refcnt,
                0
            );
        }
        return;
    }

    atomic_fetch_add_explicit(&ctx->total_size, allocated, memory_order_relaxed);
    atomic_fetch_add_explicit(&ctx->files_scanned, 1, memory_order_relaxed);

    if (ctx->clone_ledger) {
        ldfs_clone_ledger_record(
            ctx->clone_ledger,
            dedup_key,
            file_path,
            file_stat,
            clone_id,
            link_id,
            ledger_unit,
            clone_refcnt,
            allocated
        );
    }

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
    int64_t interval = ctx->partial_interval > 0 ? ctx->partial_interval : LDFS_PARTIAL_INTERVAL;
    int64_t files = atomic_load_explicit(&ctx->files_scanned, memory_order_relaxed);
    if (files - ctx->last_progress_files < interval) {
        return;
    }
    pthread_mutex_lock(&ctx->progress_lock);
    if (files - ctx->last_progress_files < interval) {
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
            pthread_mutex_lock(&ctx->stats->lock);
            size_t node_count = ctx->stats->count;
            pthread_mutex_unlock(&ctx->stats->lock);
            if (node_count <= LDFS_MAX_TREE_PROGRESS_SNAPSHOT) {
                snapshot_count = ldfs_path_stats_snapshot(ctx->stats, &snapshot);
            }
        }
        ctx->tree_progress(ctx->progress_ctx, files, total, snapshot, snapshot_count);
        ldfs_free_path_stats(snapshot, snapshot_count);
    }
    pthread_mutex_unlock(&ctx->progress_lock);
}

static bool ldfs_is_hidden_name(const char *name) {
    return name[0] == '.';
}

static void ldfs_report_restricted(ldfs_walk_context *ctx, const char *path, int err) {
    if (!ctx->options || !path) {
        return;
    }
    if (ctx->options->on_restricted_path) {
        ctx->options->on_restricted_path(ctx->options->restricted_ctx, path, err);
    }
}

static bool ldfs_same_volume_fsid(const fsid_t *a, const fsid_t *b) {
    return a->val[0] == b->val[0] && a->val[1] == b->val[1];
}

static bool ldfs_should_enter_directory(
    ldfs_walk_context *ctx,
    const char *child_path,
    uint32_t entry_dev,
    const ldfs_bulk_entry *entry
) {
    if (strncmp(child_path, ctx->options->root_path, ctx->root_len) != 0) {
        return false;
    }
    char boundary = child_path[ctx->root_len];
    if (boundary != '\0' && boundary != '/') {
        return false;
    }

    if (entry->has_fsid) {
        return ldfs_same_volume_fsid(&entry->fsid, &ctx->root_fsid);
    }

    struct statfs child_fs;
    if (statfs(child_path, &child_fs) == 0) {
        return ldfs_same_volume_fsid(&child_fs.f_fsid, &ctx->root_fsid);
    }

    if (entry_dev != 0) {
        return entry_dev == (uint32_t)ctx->root_dev;
    }
    return true;
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
            int err = errno;
            if (err == EACCES || err == EPERM) {
                ldfs_report_restricted(ctx, dir_path, err);
            }
            return;
        }
    }

    struct attrlist attr_list;
    int use_physical = ctx->use_physical_size ? 1 : 0;
    ldfs_bulk_request_attrlist(&attr_list, use_physical);
    uint32_t bulk_options = ldfs_bulk_options(use_physical);

    size_t buffer_size = ldfs_effective_buffer_size(ctx->buffer_size);
    char *buffer = ldfs_thread_buffer(buffer_size);
    if (!buffer) {
        close(owned_fd);
        return;
    }

    size_t dir_len = strlen(dir_path);
    uint64_t parent_ino = 0;
    struct stat dir_stat;
    if (fstat(owned_fd, &dir_stat) == 0) {
        parent_ino = (uint64_t)dir_stat.st_ino;
    }

    ldfs_dir_probe_cache dir_probe;
    ldfs_dir_probe_reset(&dir_probe);

    for (;;) {
        if (ldfs_is_cancelled(ctx)) {
            break;
        }

        int retcount = getattrlistbulk(owned_fd, &attr_list, buffer, buffer_size, bulk_options);
        if (retcount < 0) {
            break;
        }
        if (retcount == 0) {
            break;
        }

        char *cursor = buffer;
        char *buffer_end = buffer + buffer_size;
        for (int index = 0; index < retcount; index++) {
            cursor = (char *)((uintptr_t)(cursor + 3) & ~(uintptr_t)3);
            if (cursor + sizeof(attribute_set_t) > buffer_end) {
                break;
            }
            attribute_set_t returned;
            memcpy(&returned, cursor, sizeof(returned));
            cursor += sizeof(returned);

            ldfs_bulk_entry entry;
            if (ldfs_bulk_parse_entry(&cursor, buffer_end, &returned, &entry) != 0) {
                break;
            }

            if (entry.error != 0 || entry.name[0] == '\0') {
                continue;
            }
            if (strcmp(entry.name, ".") == 0 || strcmp(entry.name, "..") == 0) {
                continue;
            }
            if (ctx->options->skip_hidden && ldfs_is_hidden_name(entry.name)) {
                continue;
            }

            size_t name_len = strlen(entry.name);
            if (dir_len + 1 + name_len + 1 > PATH_MAX) {
                continue;
            }

            char child_path[PATH_MAX];
            memcpy(child_path, dir_path, dir_len);
            child_path[dir_len] = '/';
            memcpy(child_path + dir_len + 1, entry.name, name_len + 1);

            if (entry.obj_type == VDIR) {
                if (!ctx->options->firm_links && entry.is_firmlink) {
                    continue;
                }
                if (!ldfs_should_enter_directory(ctx, child_path, entry.dev, &entry)) {
                    continue;
                }
                int subfd = openat(owned_fd, entry.name, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
                if (subfd < 0) {
                    int err = errno;
                    if (err == EACCES || err == EPERM) {
                        ldfs_report_restricted(ctx, child_path, err);
                    }
                    continue;
                }
                if (ctx->stats) {
                    ldfs_path_stats_mark_directory(ctx->stats, child_path);
                }
                if (ldfs_work_queue_push_child(
                        ctx->queue,
                        dir_path,
                        dir_len,
                        entry.name,
                        name_len,
                        subfd
                    )
                    != 0) {
                    close(subfd);
                }
                continue;
            }

            if (entry.obj_type == VREG) {
                if (entry.clone_id == 0 && !entry.has_link_id) {
                    int duplicate_fingerprint = ldfs_dir_probe_note_fingerprint(
                        &dir_probe,
                        entry.alloc_size,
                        entry.data_length
                    );
                    if (ldfs_bulk_should_probe_clone_metadata(&entry) || duplicate_fingerprint) {
                        ldfs_bulk_enrich_clone_from_name(owned_fd, entry.name, &entry);
                    }
                }
                int64_t size;
                if (entry.alloc_size > 0) {
                    size = (int64_t)entry.alloc_size;
                } else {
                    size = (int64_t)entry.data_length;
                }
                uint32_t identity_dev = entry.dev;
                uint64_t identity_ino = entry.file_id;
                struct stat file_stat;
                memset(&file_stat, 0, sizeof(file_stat));
                const struct stat *stat_ptr = NULL;
                if (fstatat(owned_fd, entry.name, &file_stat, 0) == 0
                    || stat(child_path, &file_stat) == 0) {
                    identity_dev = (uint32_t)file_stat.st_dev;
                    identity_ino = (uint64_t)file_stat.st_ino;
                    stat_ptr = &file_stat;
                }
                ldfs_add_file(
                    ctx,
                    child_path,
                    size,
                    identity_dev,
                    identity_ino,
                    entry.clone_id,
                    entry.clone_refcnt,
                    entry.has_link_id ? entry.link_id : 0,
                    parent_ino,
                    entry.file_id,
                    stat_ptr
                );
                ldfs_maybe_publish(ctx);
            }
        }
    }

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

void ldfs_finish_walk(ldfs_walk_context *ctx) {
    if (!ctx) {
        return;
    }
    int64_t files = atomic_load_explicit(&ctx->files_scanned, memory_order_relaxed);
    int32_t groups_merged = 0;
    int64_t removed = 0;
    if (ctx->clone_ledger) {
        removed = ldfs_clone_ledger_merge(ctx->clone_ledger, &files, &groups_merged);
        if (removed > 0) {
            atomic_fetch_sub_explicit(&ctx->total_size, removed, memory_order_relaxed);
            atomic_store_explicit(&ctx->files_scanned, files, memory_order_relaxed);
        }
    }
    ctx->clone_bytes_merged = removed;
    ctx->clone_groups_merged = groups_merged;
    if (ctx->options && ctx->options->metrics_out) {
        ctx->options->metrics_out->clone_bytes_merged = removed;
        ctx->options->metrics_out->clone_groups_merged = groups_merged;
        ctx->options->metrics_out->hardlink_files_skipped =
            atomic_load_explicit(&ctx->hardlink_files_skipped, memory_order_relaxed);
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
