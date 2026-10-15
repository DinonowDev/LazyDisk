#ifndef LDFS_H
#define LDFS_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "ldfs_bulk.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef bool (*ldfs_cancel_fn)(void *ctx);

typedef void (*ldfs_restricted_fn)(void *ctx, const char *path, int error_code);

typedef struct {
    const char **prefixes;
    size_t prefix_count;
    const char *canonical_key;
} ldfs_child_entry;

typedef struct {
    int64_t clone_bytes_merged;
    int32_t clone_groups_merged;
    int64_t hardlink_files_skipped;
} ldfs_scan_metrics;

typedef struct {
    const char *root_path;
    const ldfs_child_entry *children;
    size_t child_count;
    bool skip_hidden;
    bool firm_links;
    bool use_physical_size;
    int worker_count;
    size_t buffer_size;
    bool turbo;
    ldfs_cancel_fn should_cancel;
    void *cancel_ctx;
    ldfs_restricted_fn on_restricted_path;
    void *restricted_ctx;
    ldfs_scan_metrics *metrics_out;
} ldfs_scan_options;

typedef void (*ldfs_progress_fn)(
    void *ctx,
    const int64_t *child_sizes,
    size_t child_count,
    int64_t total_size,
    int64_t files_scanned
);

typedef struct {
    const char *path;
    int64_t size;
    int32_t file_count;
    uint8_t is_directory;
} ldfs_path_stat;

typedef struct {
    const char *root_path;
    size_t max_depth;
    bool skip_hidden;
    bool firm_links;
    bool use_physical_size;
    int worker_count;
    size_t buffer_size;
    bool turbo;
    const ldfs_child_entry *children;
    size_t child_count;
    ldfs_cancel_fn should_cancel;
    void *cancel_ctx;
    ldfs_restricted_fn on_restricted_path;
    void *restricted_ctx;
    ldfs_scan_metrics *metrics_out;
} ldfs_tree_options;

typedef void (*ldfs_tree_progress_fn)(
    void *ctx,
    int64_t files_scanned,
    int64_t total_size,
    const ldfs_path_stat *stats,
    size_t stats_count
);

int ldfs_scan_immediate_children(
    const ldfs_scan_options *options,
    int64_t *child_sizes_out,
    int64_t *total_size_out,
    int64_t *files_scanned_out,
    ldfs_progress_fn progress,
    void *progress_ctx
);

int ldfs_scan_tree(
    const ldfs_tree_options *options,
    int64_t *child_sizes_out,
    ldfs_path_stat **stats_out,
    size_t *stats_count_out,
    int64_t *total_size_out,
    int64_t *files_scanned_out,
    ldfs_tree_progress_fn progress,
    void *progress_ctx
);

void ldfs_free_path_stats(ldfs_path_stat *stats, size_t count);

#ifdef __cplusplus
}
#endif

#endif /* LDFS_H */
