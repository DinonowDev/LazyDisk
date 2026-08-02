#ifndef LDFS_INTERNAL_H
#define LDFS_INTERNAL_H

#include "ldfs.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define LDFS_DEFAULT_BUFFER (128 * 1024)
#define LDFS_TURBO_BUFFER (256 * 1024)
#define LDFS_DEFAULT_WORKERS 5
#define LDFS_TURBO_WORKERS 8
#define LDFS_MAX_WORKERS 12
#define LDFS_PARTIAL_INTERVAL 96
#define LDFS_INODE_BUCKETS 65536
#define LDFS_PATH_BUCKETS 262144

typedef struct {
    char *path;
} ldfs_queue_item;

typedef struct {
    ldfs_queue_item *items;
    size_t head;
    size_t tail;
    size_t capacity;
    pthread_mutex_t lock;
} ldfs_work_queue;

typedef struct {
    uint64_t *buckets;
    pthread_mutex_t locks[LDFS_INODE_BUCKETS];
} ldfs_inode_hash;

typedef struct {
    char *path;
    int64_t size;
    int32_t file_count;
    uint8_t is_directory;
} ldfs_path_stat_node;

typedef struct {
    ldfs_path_stat_node *nodes;
    size_t count;
    size_t capacity;
    ldfs_path_stat_node **buckets;
    size_t bucket_count;
    pthread_mutex_t lock;
} ldfs_path_stats;

typedef struct {
    const ldfs_scan_options *options;
    int64_t *child_sizes;
    ldfs_path_stats *stats;
    ldfs_inode_hash *inodes;
    ldfs_work_queue *queue;
    dev_t root_dev;
    size_t root_len;
    size_t max_depth;
    atomic_int_least64_t total_size;
    atomic_int_least64_t files_scanned;
    pthread_mutex_t child_lock;
    ldfs_progress_fn child_progress;
    ldfs_tree_progress_fn tree_progress;
    void *progress_ctx;
    int64_t last_progress_files;
    pthread_mutex_t progress_lock;
    size_t buffer_size;
} ldfs_walk_context;

void ldfs_work_queue_init(ldfs_work_queue *queue);
void ldfs_work_queue_free(ldfs_work_queue *queue);
int ldfs_work_queue_push(ldfs_work_queue *queue, const char *path);
char *ldfs_work_queue_pop(ldfs_work_queue *queue);
size_t ldfs_work_queue_size(ldfs_work_queue *queue);

ldfs_inode_hash *ldfs_inode_hash_create(void);
void ldfs_inode_hash_free(ldfs_inode_hash *hash);
bool ldfs_inode_hash_seen(ldfs_inode_hash *hash, uint64_t inode);

ldfs_path_stats *ldfs_path_stats_create(void);
void ldfs_path_stats_free(ldfs_path_stats *stats);
void ldfs_path_stats_mark_directory(ldfs_path_stats *stats, const char *path);
void ldfs_path_stats_add_size(ldfs_path_stats *stats, const char *path, int64_t size);
void ldfs_path_stats_add_file(ldfs_path_stats *stats, const char *parent_path, int64_t size);
size_t ldfs_path_stats_export(ldfs_path_stats *stats, ldfs_path_stat **out);
size_t ldfs_path_stats_snapshot(ldfs_path_stats *stats, ldfs_path_stat **out);

int ldfs_match_child_index(const ldfs_child_entry *children, size_t child_count, const char *file_path);
void ldfs_scan_directory(ldfs_walk_context *ctx, const char *dir_path);
void ldfs_run_workers(ldfs_walk_context *ctx, int worker_count, void (*worker_fn)(ldfs_walk_context *));
void ldfs_worker_loop(ldfs_walk_context *ctx);

size_t ldfs_effective_buffer_size(size_t requested);
int ldfs_effective_worker_count(int requested, bool turbo);

#endif /* LDFS_INTERNAL_H */
