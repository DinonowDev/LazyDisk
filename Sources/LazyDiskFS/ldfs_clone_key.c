#include "ldfs_clone_key.h"

#include <string.h>
#include <sys/stat.h>

uint64_t ldfs_clone_primary_key(uint64_t clone_id, uint64_t link_id) {
    if (clone_id != 0) {
        return clone_id;
    }
    if (link_id != 0) {
        return (uint64_t)1 << 63 | link_id;
    }
    return 0;
}

uint64_t ldfs_clone_fallback_key(
    const char *file_path,
    const struct stat *file_stat,
    uint64_t parent_ino,
    uint64_t apfs_file_id
) {
    if (!file_stat) {
        return 0;
    }
    (void)file_path;
    uint64_t hash = parent_ino;
    hash ^= (uint64_t)file_stat->st_ino;
    hash ^= apfs_file_id;
    hash ^= (uint64_t)file_stat->st_blocks;
    hash ^= (uint64_t)file_stat->st_size;
    return (uint64_t)3 << 62 | (hash & ((uint64_t)1 << 62) - 1);
}
