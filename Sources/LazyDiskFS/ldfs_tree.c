#include "ldfs.h"
#include "ldfs_internal.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int ldfs_run_walk(ldfs_walk_context *ctx, const char *root_path, bool turbo) {
    struct stat root_stat;
    if (stat(root_path, &root_stat) == 0) {
        ctx->root_dev = root_stat.st_dev;
    } else {
        ctx->root_dev = 0;
    }
    memset(&ctx->root_fsid, 0, sizeof(ctx->root_fsid));
    struct statfs root_fs;
    if (statfs(root_path, &root_fs) == 0) {
        ctx->root_fsid = root_fs.f_fsid;
    }
    ctx->root_len = strlen(root_path);

    int root_fd = open(root_path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (root_fd < 0) {
        return -errno;
    }
    if (ldfs_work_queue_push_fd(ctx->queue, root_path, root_fd) != 0) {
        close(root_fd);
        return -ENOMEM;
    }

    int worker_count = ldfs_effective_worker_count(ctx->options->worker_count, ctx->options->turbo);
    ldfs_run_workers(ctx, worker_count, ldfs_worker_loop);
    ldfs_finish_walk(ctx);
    return 0;
}

static int ldfs_execute_scan(
    const ldfs_scan_options *options,
    int64_t *child_sizes_out,
    ldfs_path_stats *stats,
    size_t max_depth,
    ldfs_progress_fn child_progress,
    ldfs_tree_progress_fn tree_progress,
    void *progress_ctx,
    int64_t *total_size_out,
    int64_t *files_scanned_out
) {
    if (!options || !options->root_path || !total_size_out || !files_scanned_out) {
        return -EINVAL;
    }
    if (options->child_count > 0 && !child_sizes_out) {
        return -EINVAL;
    }

    if (options->child_count > 0 && child_sizes_out) {
        memset(child_sizes_out, 0, options->child_count * sizeof(int64_t));
    }

    ldfs_work_queue queue;
    ldfs_work_queue_init(&queue);

    ldfs_inode_hash *inodes = ldfs_inode_hash_create();
    ldfs_clone_hash *clones = ldfs_clone_hash_create();
    ldfs_clone_ledger *clone_ledger = ldfs_clone_ledger_create();
    if (!inodes || !clones || !clone_ledger) {
        ldfs_inode_hash_free(inodes);
        ldfs_clone_hash_free(clones);
        ldfs_clone_ledger_free(clone_ledger);
        ldfs_work_queue_free(&queue);
        return -ENOMEM;
    }

    ldfs_walk_context ctx = {
        .options = options,
        .child_sizes = child_sizes_out,
        .stats = stats,
        .inodes = inodes,
        .clones = clones,
        .clone_ledger = clone_ledger,
        .queue = &queue,
        .use_physical_size = options->use_physical_size,
        .root_dev = 0,
        .root_fsid = {0},
        .root_len = 0,
        .max_depth = max_depth,
        .child_progress = child_progress,
        .tree_progress = tree_progress,
        .progress_ctx = progress_ctx,
        .last_progress_files = 0,
        .partial_interval = LDFS_PARTIAL_INTERVAL,
        .buffer_size = options->buffer_size,
        .clone_bytes_merged = 0,
        .clone_groups_merged = 0,
    };
    atomic_init(&ctx.total_size, 0);
    atomic_init(&ctx.files_scanned, 0);
    atomic_init(&ctx.hardlink_files_skipped, 0);
    pthread_mutex_init(&ctx.child_lock, NULL);
    pthread_mutex_init(&ctx.progress_lock, NULL);

    int status = ldfs_run_walk(&ctx, options->root_path, options->turbo);
    if (status != 0) {
        ldfs_inode_hash_free(inodes);
        ldfs_clone_hash_free(clones);
        ldfs_clone_ledger_free(clone_ledger);
        ldfs_work_queue_free(&queue);
        pthread_mutex_destroy(&ctx.child_lock);
        pthread_mutex_destroy(&ctx.progress_lock);
        return status;
    }

    if (child_progress && child_sizes_out) {
        int64_t files = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);
        int64_t total = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
        child_progress(progress_ctx, child_sizes_out, options->child_count, total, files);
    } else if (tree_progress) {
        int64_t files = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);
        int64_t total = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
        ldfs_path_stat *snapshot = NULL;
        size_t snapshot_count = 0;
        if (stats) {
            snapshot_count = ldfs_path_stats_snapshot(stats, &snapshot);
        }
        tree_progress(progress_ctx, files, total, snapshot, snapshot_count);
        ldfs_free_path_stats(snapshot, snapshot_count);
    }

    *total_size_out = atomic_load_explicit(&ctx.total_size, memory_order_relaxed);
    *files_scanned_out = atomic_load_explicit(&ctx.files_scanned, memory_order_relaxed);

    ldfs_inode_hash_free(inodes);
    ldfs_clone_hash_free(clones);
    ldfs_clone_ledger_free(clone_ledger);
    ldfs_work_queue_free(&queue);
    pthread_mutex_destroy(&ctx.child_lock);
    pthread_mutex_destroy(&ctx.progress_lock);
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
    return ldfs_execute_scan(
        options,
        child_sizes_out,
        NULL,
        0,
        progress,
        NULL,
        progress_ctx,
        total_size_out,
        files_scanned_out
    );
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

    ldfs_path_stats *stats = ldfs_path_stats_create();
    if (!stats) {
        return -ENOMEM;
    }

    size_t tree_depth = options->max_depth;
    if (tree_depth == 0) {
        tree_depth = 64;
    }
    bool accumulate_paths = tree_depth > 0;

    ldfs_scan_options scan_options = {
        .root_path = options->root_path,
        .children = options->children,
        .child_count = options->child_count,
        .skip_hidden = options->skip_hidden,
        .firm_links = options->firm_links,
        .use_physical_size = options->use_physical_size,
        .worker_count = options->worker_count,
        .buffer_size = options->buffer_size,
        .turbo = options->turbo,
        .should_cancel = options->should_cancel,
        .cancel_ctx = options->cancel_ctx,
        .on_restricted_path = options->on_restricted_path,
        .restricted_ctx = options->restricted_ctx,
        .metrics_out = options->metrics_out,
    };

    int status = ldfs_execute_scan(
        &scan_options,
        child_sizes_out,
        accumulate_paths ? stats : NULL,
        accumulate_paths ? tree_depth : 0,
        NULL,
        progress,
        progress_ctx,
        total_size_out,
        files_scanned_out
    );
    if (status != 0) {
        ldfs_path_stats_free(stats);
        return status;
    }

    if (child_sizes_out && options->child_count > 0) {
        ldfs_path_stats_backfill_child_sizes(
            stats,
            options->children,
            options->child_count,
            child_sizes_out
        );
    }

    size_t root_len = strlen(options->root_path);
    size_t export_count = ldfs_path_stats_export_within_depth(
        stats,
        options->root_path,
        root_len,
        tree_depth,
        stats_out
    );
    if (export_count == 0) {
        export_count = ldfs_path_stats_export(stats, stats_out);
    }
    *stats_count_out = export_count;
    ldfs_path_stats_free(stats);
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
