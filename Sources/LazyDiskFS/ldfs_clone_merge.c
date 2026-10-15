#include "ldfs_internal.h"
#include "ldfs_bulk.h"
#include "ldfs_clone_key.h"

#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

typedef struct ldfs_clone_group {
    uint64_t key;
    int64_t unit_size;
    int64_t bytes_counted;
    uint32_t files_seen;
    uint32_t max_refcnt;
    struct ldfs_clone_group *next;
} ldfs_clone_group;

struct ldfs_clone_ledger {
    ldfs_clone_group *buckets[LDFS_INODE_BUCKETS];
    pthread_mutex_t bucket_locks[LDFS_INODE_BUCKETS];
};

ldfs_clone_ledger *ldfs_clone_ledger_create(void) {
    ldfs_clone_ledger *ledger = calloc(1, sizeof(ldfs_clone_ledger));
    if (!ledger) {
        return NULL;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_init(&ledger->bucket_locks[i], NULL);
    }
    return ledger;
}

void ldfs_clone_ledger_free(ldfs_clone_ledger *ledger) {
    if (!ledger) {
        return;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        ldfs_clone_group *entry = ledger->buckets[i];
        while (entry) {
            ldfs_clone_group *next = entry->next;
            free(entry);
            entry = next;
        }
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_destroy(&ledger->bucket_locks[i]);
    }
    free(ledger);
}

static ldfs_clone_group *ldfs_clone_group_find_or_insert_locked(
    ldfs_clone_ledger *ledger,
    size_t bucket,
    uint64_t key,
    int64_t unit_size,
    uint32_t refcnt
) {
    for (ldfs_clone_group *entry = ledger->buckets[bucket]; entry; entry = entry->next) {
        if (entry->key == key) {
            entry->files_seen += 1;
            if (refcnt > entry->max_refcnt) {
                entry->max_refcnt = refcnt;
            }
            if (unit_size > entry->unit_size) {
                entry->unit_size = unit_size;
            }
            return entry;
        }
    }

    ldfs_clone_group *node = malloc(sizeof(ldfs_clone_group));
    if (!node) {
        return NULL;
    }
    node->key = key;
    node->unit_size = unit_size;
    node->bytes_counted = 0;
    node->files_seen = 1;
    node->max_refcnt = refcnt > 0 ? refcnt : 1;
    node->next = ledger->buckets[bucket];
    ledger->buckets[bucket] = node;
    return node;
}

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
) {
    if (!ledger || unit_size <= 0) {
        return;
    }
    uint64_t key = dedup_key != 0 ? dedup_key : ldfs_clone_primary_key(clone_id, link_id);
    if (key == 0 && file_path && file_stat) {
        key = ldfs_clone_fallback_key(file_path, file_stat, 0, 0);
    }
    if (key == 0) {
        return;
    }
    size_t bucket = (size_t)((key >> 8) % LDFS_INODE_BUCKETS);
    pthread_mutex_lock(&ledger->bucket_locks[bucket]);
    ldfs_clone_group *group = ldfs_clone_group_find_or_insert_locked(ledger, bucket, key, unit_size, refcnt);
    if (group && bytes_added > 0) {
        group->bytes_counted += bytes_added;
    }
    pthread_mutex_unlock(&ledger->bucket_locks[bucket]);
}

int64_t ldfs_clone_ledger_merge(ldfs_clone_ledger *ledger, int64_t *files_scanned_out, int32_t *groups_merged_out) {
    if (!ledger) {
        return 0;
    }
    int64_t bytes_to_remove = 0;
    int64_t files_to_remove = 0;
    int32_t groups_merged = 0;

    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_lock(&ledger->bucket_locks[i]);
        for (ldfs_clone_group *entry = ledger->buckets[i]; entry; entry = entry->next) {
            if (entry->unit_size <= 0) {
                continue;
            }
            uint32_t effective_files = entry->files_seen;
            if (entry->max_refcnt > effective_files) {
                effective_files = entry->max_refcnt;
            }
            if (effective_files <= 1) {
                continue;
            }
            int64_t excess_files = (int64_t)effective_files - 1;
            bytes_to_remove += excess_files * entry->unit_size;
            files_to_remove += excess_files;
            groups_merged += 1;
        }
        pthread_mutex_unlock(&ledger->bucket_locks[i]);
    }

    if (groups_merged_out) {
        *groups_merged_out = groups_merged;
    }

    if (files_scanned_out && files_to_remove > 0) {
        *files_scanned_out -= files_to_remove;
        if (*files_scanned_out < 0) {
            *files_scanned_out = 0;
        }
    }
    return bytes_to_remove;
}
