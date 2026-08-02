#include "ldfs.h"
#include "ldfs_internal.h"

#include <errno.h>
#include <string.h>
#include <sys/stat.h>

static int ldfs_run_walk(ldfs_walk_context *ctx, const char *root_path, bool turbo) {
    struct stat root_stat;
    if (stat(root_path, &root_stat) == 0) {
        ctx->root_dev = root_stat.st_dev;
    } else {
        ctx->root_dev = 0;
    }
    ctx->root_len = strlen(root_path);

    if (ldfs_work_queue_push(ctx->queue, root_path) != 0) {
        return -ENOMEM;
    }

    int worker_count = ldfs_effective_worker_count(ctx->options->worker_count, turbo);
    ldfs_run_workers(ctx, worker_count, ldfs_worker_loop);
    return 0;
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

    ldfs_work_queue queue;
    ldfs_work_queue_init(&queue);

    ldfs_inode_hash *inodes = ldfs_inode_hash_create();
    if (!inodes) {
        ldfs_work_queue_free(&queue);
        return -ENOMEM;
    }

    ldfs_walk_context ctx = {
        .options = options,
        .child_sizes = child_sizes_out,
        .stats = NULL,
        .inodes = inodes,
        .queue = &queue,
        .max_depth = 0,
        .child_progress = progress,
        .tree_progress = NULL,
        .progress_ctx = progress_ctx,
        .last_progress_files = 0,
        .buffer_size = options->buffer_size,
    };
    atomic_init(&ctx.total_size, 0);
    atomic_init(&ctx.files_scanned, 0);
    pthread_mutex_init(&ctx.child_lock, NULL);
    pthread_mutex_init(&ctx.progress_lock, NULL);

    int status = ldfs_run_walk(&ctx, options->root_path, options->turbo);
    if (status != 0) {
        ldfs_inode_hash_free(inodes);
        ldfs_work_queue_free(&queue);
        return status;
    }

    if (progress) {
        int64_t files = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);
        int64_t total = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
        progress(progress_ctx, child_sizes_out, options->child_count, total, files);
    }

    *total_size_out = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
    *files_scanned_out = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);

    ldfs_inode_hash_free(inodes);
    ldfs_work_queue_free(&queue);
    pthread_mutex_destroy(&ctx.child_lock);
    pthread_mutex_destroy(&ctx.progress_lock);
    return 0;
}

int ldfs_scan_tree(
    const ldfs_tree_options *options,
    int64_t *child_sizes_out,
    ldfs_path_stat **stats_out,
    size_t *stats_count_out,
    int64_t *total_size_out,
    int64_t *files_scanned_out,
    ldfs_tree_progress_fn progress,
    void *progress_ctx
) {
    if (!options || !options->root_path || !stats_out || !stats_count_out
        || !total_size_out || !files_scanned_out) {
        return -EINVAL;
    }

  if (options->child_count > 0 && child_sizes_out) {
        memset(child_sizes_out, 0, options->child_count * sizeof(int64_t));
    }

    ldfs_work_queue queue;
    ldfs_work_queue_init(&queue);

    ldfs_inode_hash *inodes = ldfs_inode_hash_create();
    ldfs_path_stats *stats = ldfs_path_stats_create();
    if (!inodes || !stats) {
        ldfs_inode_hash_free(inodes);
        ldfs_path_stats_free(stats);
        ldfs_work_queue_free(&queue);
        return -ENOMEM;
    }

    ldfs_scan_options scan_options = {
        .root_path = options->root_path,
        .children = options->children,
        .child_count = options->child_count,
        .skip_hidden = options->skip_hidden,
        .worker_count = options->worker_count,
        .buffer_size = options->buffer_size,
        .turbo = options->turbo,
        .should_cancel = options->should_cancel,
        .cancel_ctx = options->cancel_ctx,
    };

    ldfs_walk_context ctx = {
        .options = &scan_options,
        .child_sizes = child_sizes_out,
        .stats = stats,
        .inodes = inodes,
        .queue = &queue,
        .max_depth = options->max_depth,
        .child_progress = NULL,
        .tree_progress = progress,
        .progress_ctx = progress_ctx,
        .last_progress_files = 0,
        .buffer_size = options->buffer_size,
    };
    atomic_init(&ctx.total_size, 0);
    atomic_init(&ctx.files_scanned, 0);
    pthread_mutex_init(&ctx.child_lock, NULL);
    pthread_mutex_init(&ctx.progress_lock, NULL);

    ldfs_path_stats_mark_directory(stats, options->root_path);

    int status = ldfs_run_walk(&ctx, options->root_path, options->turbo);
    if (status != 0) {
        ldfs_inode_hash_free(inodes);
        ldfs_path_stats_free(stats);
        ldfs_work_queue_free(&queue);
        return status;
    }

    if (progress) {
        int64_t files = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);
        int64_t total = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
        ldfs_path_stat *snapshot = NULL;
        size_t snapshot_count = 0;
        if (stats) {
            snapshot_count = ldfs_path_stats_snapshot(stats, &snapshot);
        }
        progress(progress_ctx, files, total, snapshot, snapshot_count);
        ldfs_free_path_stats(snapshot, snapshot_count);
    }

    *stats_count_out = ldfs_path_stats_export(stats, stats_out);
    *total_size_out = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
    *files_scanned_out = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);

    ldfs_inode_hash_free(inodes);
    ldfs_path_stats_free(stats);
    ldfs_work_queue_free(&queue);
    pthread_mutex_destroy(&ctx.child_lock);
    pthread_mutex_destroy(&ctx.progress_lock);
    return 0;
}

void ldfs_free_path_stats(ldfs_path_stat *stats, size_t count) {
    if (!stats) {
        return;
    }
    for (size_t i = 0; i < count; i++) {
        free((void *)stats[i].path);
    }
    free(stats);
}
