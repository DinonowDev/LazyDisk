#ifndef LDFS_BULK_H
#define LDFS_BULK_H

#include <sys/attr.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint32_t error;
    char name[256];
    fsobj_type_t obj_type;
    uint64_t file_id;
    uint32_t flags;
    uint32_t dev;
    off_t data_length;
    off_t alloc_size;
    fsid_t fsid;
    uint64_t clone_id;
    uint32_t clone_refcnt;
    uint64_t link_id;
    int has_fsid;
    int has_link_id;
    int is_firmlink;
} ldfs_bulk_entry;

int ldfs_bulk_enrich_clone_from_name(int dirfd, const char *name, ldfs_bulk_entry *out);

/// True when a lightweight getattrlist probe may resolve APFS clone metadata (CLONEID missing in bulk).
int ldfs_bulk_should_probe_clone_metadata(const ldfs_bulk_entry *entry);

#define LDFS_DIR_PROBE_SLOT_COUNT 128

typedef struct {
    uint64_t keys[LDFS_DIR_PROBE_SLOT_COUNT];
    uint8_t counts[LDFS_DIR_PROBE_SLOT_COUNT];
} ldfs_dir_probe_cache;

void ldfs_dir_probe_reset(ldfs_dir_probe_cache *cache);

/// Returns 1 when a duplicate (alloc,data) fingerprint appears in the same directory.
int ldfs_dir_probe_note_fingerprint(ldfs_dir_probe_cache *cache, off_t alloc_size, off_t data_length);

void ldfs_bulk_request_attrlist(struct attrlist *attr_list, int use_physical_size);
uint32_t ldfs_bulk_options(int use_physical_size);

/* Advances *cursor; returns 0 on success, -1 if malformed or out of bounds. */
int ldfs_bulk_parse_entry(
    char **cursor,
    const char *buffer_end,
    const attribute_set_t *returned,
    ldfs_bulk_entry *out
);

/* Writes one synthetic bulk record for unit tests; returns bytes written or 0 on failure. */
size_t ldfs_bulk_pack_synthetic_entry(
    uint8_t *buffer,
    size_t capacity,
    const ldfs_bulk_entry *seed,
    attribute_set_t *returned_out
);

#endif /* LDFS_BULK_H */
