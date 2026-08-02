#ifndef LDFS_H
#define LDFS_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef bool (*ldfs_cancel_fn)(void *ctx);

typedef struct {
    const char **prefixes;
    size_t prefix_count;
    const char *canonical_key;
} ldfs_child_entry;

typedef struct {
    const char *root_path;
    const ldfs_child_entry *children;
    size_t child_count;
    bool skip_hidden;
    int worker_count;
    ldfs_cancel_fn should_cancel;
    void *cancel_ctx;
} ldfs_scan_options;

typedef void (*ldfs_progress_fn)(
    void *ctx,
    const int64_t *child_sizes,
    size_t child_count,
    int64_t total_size,
    int64_t files_scanned
);

/// Walks `root_path` and accumulates allocated sizes into per-child buckets.
/// Returns 0 on success, negative errno-style code on failure.
int ldfs_scan_immediate_children(
    const ldfs_scan_options *options,
    int64_t *child_sizes_out,
    int64_t *total_size_out,
    int64_t *files_scanned_out,
    ldfs_progress_fn progress,
    void *progress_ctx
);

#ifdef __cplusplus
}
#endif

#endif /* LDFS_H */
