#ifndef LDFS_INTERNAL_H
#define LDFS_INTERNAL_H

#include "ldfs.h"

#include <pthread.h>
#include <sys/mount.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define LDFS_DEFAULT_BUFFER 0x4000
#define LDFS_TURBO_BUFFER 0x8000
#define LDFS_DEFAULT_WORKERS 5
#define LDFS_TURBO_WORKERS 8
#define LDFS_MAX_WORKERS 12
#define LDFS_PARTIAL_INTERVAL 96
#define LDFS_TREE_PARTIAL_INTERVAL 512
#define LDFS_MAX_TREE_PROGRESS_SNAPSHOT 16384
#define LDFS_INODE_BUCKETS 65536
#define LDFS_PATH_BUCKETS 262144
#define LDFS_NO_INDEX ((size_t)-1)

typedef struct {
    char *path;
    int dirfd;
} ldfs_queue_item;

typedef struct {
    ldfs_queue_item *items;
    size_t head;
    size_t tail;
    size_t capacity;
    size_t inflight;
    int closed;
    pthread_mutex_t lock;
    pthread_cond_t cond;
} ldfs_work_queue;

typedef struct ldfs_inode_entry {
    uint32_t dev;
    uint64_t ino;
    struct ldfs_inode_entry *next;
} ldfs_inode_entry;

typedef struct {
    ldfs_inode_entry *buckets[LDFS_INODE_BUCKETS];
    pthread_mutex_t locks[LDFS_INODE_BUCKETS];
} ldfs_inode_hash;

typedef struct ldfs_clone_entry {
    uint64_t clone_id;
    struct ldfs_clone_entry *next;
} ldfs_clone_entry;

typedef struct {
    ldfs_clone_entry *buckets[LDFS_INODE_BUCKETS];
    pthread_mutex_t locks[LDFS_INODE_BUCKETS];
} ldfs_clone_hash;

typedef struct ldfs_clone_ledger ldfs_clone_ledger;

typedef struct {
    char *path;
    int64_t size;
    int32_t file_count;
    uint8_t is_directory;
    size_t next_in_bucket;
} ldfs_path_stat_node;

typedef struct {
    ldfs_path_stat_node *nodes;
    size_t count;
    size_t capacity;
    size_t *bucket_heads;
    size_t bucket_count;
    pthread_mutex_t lock;
} ldfs_path_stats;

typedef struct {
    const ldfs_scan_options *options;
    int64_t *child_sizes;
    ldfs_path_stats *stats;
    ldfs_inode_hash *inodes;
    ldfs_clone_hash *clones;
    ldfs_clone_ledger *clone_ledger;
    ldfs_work_queue *queue;
    bool use_physical_size;
    dev_t root_dev;
    fsid_t root_fsid;
    size_t root_len;
    size_t max_depth;
    atomic_int_least64_t total_size;
    atomic_int_least64_t files_scanned;
    atomic_int_least64_t hardlink_files_skipped;
    int64_t clone_bytes_merged;
    int32_t clone_groups_merged;
    pthread_mutex_t child_lock;
    ldfs_progress_fn child_progress;
    ldfs_tree_progress_fn tree_progress;
    void *progress_ctx;
    int64_t last_progress_files;
    int64_t partial_interval;
    pthread_mutex_t progress_lock;
    size_t buffer_size;
} ldfs_walk_context;

void ldfs_work_queue_init(ldfs_work_queue *queue);
void ldfs_work_queue_free(ldfs_work_queue *queue);
int ldfs_work_queue_push_fd(ldfs_work_queue *queue, const char *path, int dirfd);
int ldfs_work_queue_push_owned(ldfs_work_queue *queue, char *path, int dirfd);
int ldfs_work_queue_push_child(
    ldfs_work_queue *queue,
    const char *parent,
    size_t parent_len,
    const char *name,
    size_t name_len,
    int dirfd
);
ldfs_queue_item ldfs_work_queue_pop_wait(ldfs_work_queue *queue);
void ldfs_work_queue_finish_item(ldfs_work_queue *queue);
size_t ldfs_work_queue_size(ldfs_work_queue *queue);

ldfs_inode_hash *ldfs_inode_hash_create(void);
void ldfs_inode_hash_free(ldfs_inode_hash *hash);
bool ldfs_inode_hash_seen(ldfs_inode_hash *hash, uint32_t dev, uint64_t ino);

ldfs_clone_hash *ldfs_clone_hash_create(void);
void ldfs_clone_hash_free(ldfs_clone_hash *hash);
bool ldfs_clone_hash_seen(ldfs_clone_hash *hash, uint64_t clone_id);

ldfs_clone_ledger *ldfs_clone_ledger_create(void);
void ldfs_clone_ledger_free(ldfs_clone_ledger *ledger);
void ldfs_clone_ledger_record(
    ldfs_clone_ledger *ledger,
    uint64_t dedup_key,
    const char *file_path,
    const struct stat *file_stat,
    uint64_t clone_id,
    uint64_t link_id,
    int64_t unit_size,
    uint32_t refcnt,
    int64_t bytes_added
);
int64_t ldfs_clone_ledger_merge(ldfs_clone_ledger *ledger, int64_t *files_scanned_out, int32_t *groups_merged_out);

ldfs_path_stats *ldfs_path_stats_create(void);
void ldfs_path_stats_free(ldfs_path_stats *stats);
void ldfs_path_stats_mark_directory(ldfs_path_stats *stats, const char *path);
void ldfs_path_stats_add_size(ldfs_path_stats *stats, const char *path, int64_t size);
void ldfs_path_stats_add_ancestor_sizes(ldfs_path_stats *stats, const char *root, size_t root_len, const char *relative, size_t max_depth, int64_t size);
void ldfs_path_stats_add_file(ldfs_path_stats *stats, const char *parent_path, int64_t size);
size_t ldfs_path_stats_export(ldfs_path_stats *stats, ldfs_path_stat **out);
size_t ldfs_path_stats_export_within_depth(
    ldfs_path_stats *stats,
    const char *root,
    size_t root_len,
    size_t max_relative_depth,
    ldfs_path_stat **out
);
void ldfs_path_stats_backfill_child_sizes(
    ldfs_path_stats *stats,
    const ldfs_child_entry *children,
    size_t child_count,
    const int64_t *child_sizes
);
size_t ldfs_path_stats_snapshot(ldfs_path_stats *stats, ldfs_path_stat **out);

int ldfs_match_child_index(const ldfs_child_entry *children, size_t child_count, const char *file_path);
void ldfs_scan_directory_fd(ldfs_walk_context *ctx, const char *dir_path, int dirfd);
void ldfs_run_workers(ldfs_walk_context *ctx, int worker_count, void (*worker_fn)(ldfs_walk_context *));
void ldfs_worker_loop(ldfs_walk_context *ctx);
void ldfs_finish_walk(ldfs_walk_context *ctx);

size_t ldfs_effective_buffer_size(size_t requested);
int ldfs_effective_worker_count(int requested, bool turbo);
char *ldfs_thread_buffer(size_t needed);

#endif /* LDFS_INTERNAL_H */
