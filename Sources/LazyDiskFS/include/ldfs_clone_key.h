#ifndef LDFS_CLONE_KEY_H
#define LDFS_CLONE_KEY_H

#include <stdint.h>
#include <sys/types.h>

struct stat;

/// Primary APFS clone identity: CLONEID, else stable link_id namespace (matches Daisy-style clone tables).
uint64_t ldfs_clone_primary_key(uint64_t clone_id, uint64_t link_id);

uint64_t ldfs_clone_fallback_key(
    const char *file_path,
    const struct stat *file_stat,
    uint64_t parent_ino,
    uint64_t apfs_file_id
);

#endif /* LDFS_CLONE_KEY_H */
