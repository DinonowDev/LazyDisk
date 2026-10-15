#include "ldfs_internal.h"

#include <pthread.h>
#include <stdlib.h>
#include <string.h>

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

void ldfs_path_stats_add_ancestor_sizes(
    ldfs_path_stats *stats,
    const char *root,
    size_t root_len,
    const char *relative,
    size_t max_depth,
    int64_t size
) {
    if (!stats || size <= 0 || max_depth == 0 || !relative || *relative == '\0') {
        return;
    }

    char accum[PATH_MAX];
    if (root_len + 1 >= sizeof(accum)) {
        return;
    }
    memcpy(accum, root, root_len);
    accum[root_len] = '\0';
    size_t accum_len = root_len;

    const char *cursor = relative;
    size_t depth = 0;

    pthread_mutex_lock(&stats->lock);
    while (*cursor) {
        const char *slash = strchr(cursor, '/');
        size_t part_len = slash ? (size_t)(slash - cursor) : strlen(cursor);
        if (part_len == 0) {
            break;
        }
        if (accum_len + 1 + part_len + 1 > sizeof(accum)) {
            break;
        }
        accum[accum_len] = '/';
        memcpy(accum + accum_len + 1, cursor, part_len);
        accum_len += 1 + part_len;
        accum[accum_len] = '\0';

        if (!slash) {
            char parent[PATH_MAX];
            size_t file_len = accum_len;
            if (file_len >= sizeof(parent)) {
                break;
            }
            memcpy(parent, accum, file_len + 1);
            char *last_slash = strrchr(parent, '/');
            if (last_slash && last_slash != parent) {
                *last_slash = '\0';
                ldfs_path_stat_node *node = ldfs_path_stats_find_locked(stats, parent, true);
                if (node) {
                    node->size += size;
                    node->file_count += 1;
                }
            }
            break;
        }

        ldfs_path_stat_node *node = ldfs_path_stats_find_locked(stats, accum, true);
        if (node) {
            node->size += size;
        }
        depth += 1;
        if (depth >= max_depth) {
            break;
        }
        cursor = slash + 1;
    }
    pthread_mutex_unlock(&stats->lock);
}

static size_t ldfs_relative_path_component_count(const char *root, size_t root_len, const char *path) {
    if (!path || strncmp(path, root, root_len) != 0) {
        return SIZE_MAX;
    }
    const char *relative = path + root_len;
    if (*relative == '/') {
        relative++;
    }
    if (*relative == '\0') {
        return 0;
    }
    size_t components = 1;
    for (const char *cursor = relative; *cursor; cursor++) {
        if (*cursor == '/') {
            components++;
        }
    }
    return components;
}

size_t ldfs_path_stats_export_within_depth(
    ldfs_path_stats *stats,
    const char *root,
    size_t root_len,
    size_t max_relative_depth,
    ldfs_path_stat **out
) {
    if (!stats || !out || !root) {
        return 0;
    }
    pthread_mutex_lock(&stats->lock);
    size_t exportable = 0;
    for (size_t i = 0; i < stats->count; i++) {
        ldfs_path_stat_node *node = &stats->nodes[i];
        if (node->size <= 0) {
            continue;
        }
        size_t depth = ldfs_relative_path_component_count(root, root_len, node->path);
        if (depth != SIZE_MAX && depth <= max_relative_depth) {
            exportable++;
        }
    }
    if (exportable == 0) {
        pthread_mutex_unlock(&stats->lock);
        *out = NULL;
        return 0;
    }
    ldfs_path_stat *entries = calloc(exportable, sizeof(ldfs_path_stat));
    if (!entries) {
        pthread_mutex_unlock(&stats->lock);
        *out = NULL;
        return 0;
    }
    size_t written = 0;
    for (size_t i = 0; i < stats->count; i++) {
        ldfs_path_stat_node *node = &stats->nodes[i];
        if (node->size <= 0 || !node->path) {
            continue;
        }
        size_t depth = ldfs_relative_path_component_count(root, root_len, node->path);
        if (depth == SIZE_MAX || depth > max_relative_depth) {
            continue;
        }
        entries[written].path = node->path;
        entries[written].size = node->size;
        entries[written].file_count = node->file_count;
        entries[written].is_directory = node->is_directory;
        node->path = NULL;
        written++;
    }
    stats->count = 0;
    for (size_t i = 0; i < stats->bucket_count; i++) {
        stats->bucket_heads[i] = LDFS_NO_INDEX;
    }
    pthread_mutex_unlock(&stats->lock);
    *out = entries;
    return written;
}

void ldfs_path_stats_backfill_child_sizes(
    ldfs_path_stats *stats,
    const ldfs_child_entry *children,
    size_t child_count,
    const int64_t *child_sizes
) {
    if (!stats || !children || !child_sizes || child_count == 0) {
        return;
    }
    for (size_t i = 0; i < child_count; i++) {
        if (child_sizes[i] <= 0) {
            continue;
        }
        const char *key = children[i].canonical_key;
        if (!key) {
            continue;
        }
        ldfs_path_stats_add_size(stats, key, child_sizes[i]);
        ldfs_path_stats_mark_directory(stats, key);
    }
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
        *out = NULL;
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
