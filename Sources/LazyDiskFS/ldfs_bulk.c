#include "ldfs_bulk.h"

#include <errno.h>
#include <string.h>
#include <sys/vnode.h>
#include <unistd.h>

static int ldfs_bulk_field_fits(const char *field, size_t bytes, const char *buffer_end) {
    return field && buffer_end && (field + bytes) <= buffer_end;
}

static size_t ldfs_bulk_append(void *dst, size_t offset, size_t cap, const void *src, size_t len) {
    if (offset + len > cap) {
        return 0;
    }
    memcpy((uint8_t *)dst + offset, src, len);
    return offset + len;
}

static char *ldfs_bulk_consume_attrreference(char *field, const char *buffer_end) {
    if (!ldfs_bulk_field_fits(field, sizeof(uint32_t), buffer_end)) {
        return NULL;
    }
    uint32_t length = 0;
    memcpy(&length, field, sizeof(length));
    size_t advance = sizeof(length) + length;
    if (!ldfs_bulk_field_fits(field, advance, buffer_end)) {
        return NULL;
    }
    return field + advance;
}

static char *ldfs_bulk_advance(char *field, size_t bytes, const char *buffer_end) {
    if (!ldfs_bulk_field_fits(field, bytes, buffer_end)) {
        return NULL;
    }
    return field + bytes;
}

/* CMNEXT attributes are returned in forkattr, in ascending bit order (sys/attr.h). */
static char *ldfs_bulk_consume_cmnext(char *field, const char *buffer_end, uint32_t forkattr, ldfs_bulk_entry *out) {
    uint32_t mask = forkattr & ATTR_CMNEXT_VALIDMASK;

    if (mask & ATTR_CMNEXT_RELPATH) {
        field = ldfs_bulk_consume_attrreference(field, buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_PRIVATESIZE) {
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_LINKID) {
        if (out) {
            memcpy(&out->link_id, field, sizeof(out->link_id));
            out->has_link_id = 1;
        }
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_NOFIRMLINKPATH) {
        if (out) {
            out->is_firmlink = 1;
        }
        field = ldfs_bulk_consume_attrreference(field, buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_REALDEVID) {
        field = ldfs_bulk_advance(field, sizeof(uint32_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_REALFSID) {
        if (out) {
            memcpy(&out->fsid, field, sizeof(out->fsid));
            out->has_fsid = 1;
        }
        field = ldfs_bulk_advance(field, sizeof(fsid_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_CLONEID) {
        if (out) {
            memcpy(&out->clone_id, field, sizeof(out->clone_id));
        }
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_EXT_FLAGS) {
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_RECURSIVE_GENCOUNT) {
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_ATTRIBUTION_TAG) {
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    if (mask & ATTR_CMNEXT_CLONE_REFCNT) {
        if (out) {
            memcpy(&out->clone_refcnt, field, sizeof(out->clone_refcnt));
        }
        field = ldfs_bulk_advance(field, sizeof(uint32_t), buffer_end);
        if (!field) {
            return NULL;
        }
    }
    return field;
}

int ldfs_bulk_enrich_clone_from_name(int dirfd, const char *name, ldfs_bulk_entry *out) {
    if (!out || !name || dirfd < 0) {
        return -1;
    }
    if (out->clone_id != 0) {
        return 0;
    }

    struct attrlist attr_list;
    ldfs_bulk_request_attrlist(&attr_list, 0);
    char buffer[4096];
    ssize_t status = getattrlistat(
        dirfd,
        name,
        &attr_list,
        buffer,
        sizeof(buffer),
        ldfs_bulk_options(0)
    );
    if (status < 0) {
        return -errno;
    }

    const char *buffer_end = buffer + status;
    attribute_set_t returned;
    memcpy(&returned, buffer, sizeof(returned));
    char *field = buffer + sizeof(returned);

    if (returned.commonattr & ATTR_CMN_RETURNED_ATTRS) {
        field = ldfs_bulk_advance(field, sizeof(attribute_set_t), buffer_end);
        if (!field) {
            return -1;
        }
    }

    if (returned.commonattr & ATTR_CMN_ERROR) {
        field = ldfs_bulk_advance(field, sizeof(uint32_t), buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.commonattr & ATTR_CMN_NAME) {
        field = ldfs_bulk_consume_attrreference(field, buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.commonattr & ATTR_CMN_OBJTYPE) {
        field = ldfs_bulk_advance(field, sizeof(fsobj_type_t), buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.commonattr & ATTR_CMN_FILEID) {
        if (out) {
            memcpy(&out->file_id, field, sizeof(out->file_id));
        }
        field = ldfs_bulk_advance(field, sizeof(uint64_t), buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.commonattr & ATTR_CMN_FLAGS) {
        field = ldfs_bulk_advance(field, sizeof(uint32_t), buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.commonattr & ATTR_CMN_DEVID) {
        field = ldfs_bulk_advance(field, sizeof(uint32_t), buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.fileattr & ATTR_FILE_DATALENGTH) {
        field = ldfs_bulk_advance(field, sizeof(off_t), buffer_end);
        if (!field) {
            return -1;
        }
    }
    if (returned.fileattr & ATTR_FILE_DATAALLOCSIZE) {
        field = ldfs_bulk_advance(field, sizeof(off_t), buffer_end);
        if (!field) {
            return -1;
        }
    }

    if (!ldfs_bulk_consume_cmnext(field, buffer_end, returned.forkattr, out)) {
        return -1;
    }
    return out->clone_id != 0 || out->has_link_id ? 0 : 1;
}

int ldfs_bulk_should_probe_clone_metadata(const ldfs_bulk_entry *entry) {
    if (!entry || entry->clone_id != 0 || entry->has_link_id) {
        return 0;
    }
    if (entry->obj_type != VREG) {
        return 0;
    }
    off_t unit = entry->alloc_size > 0 ? entry->alloc_size : entry->data_length;
    return unit >= 65536;
}

void ldfs_dir_probe_reset(ldfs_dir_probe_cache *cache) {
    if (!cache) {
        return;
    }
    memset(cache, 0, sizeof(*cache));
}

int ldfs_dir_probe_note_fingerprint(ldfs_dir_probe_cache *cache, off_t alloc_size, off_t data_length) {
    if (!cache || alloc_size <= 0) {
        return 0;
    }
    uint64_t key = ((uint64_t)(uint32_t)alloc_size << 32) ^ (uint64_t)(uint32_t)data_length;
    size_t slot = (size_t)((key >> 8) % LDFS_DIR_PROBE_SLOT_COUNT);
    if (cache->keys[slot] == key && cache->counts[slot] > 0) {
        if (cache->counts[slot] < 255) {
            cache->counts[slot] += 1;
        }
        return cache->counts[slot] >= 2;
    }
    cache->keys[slot] = key;
    cache->counts[slot] = 1;
    return 0;
}

size_t ldfs_bulk_pack_synthetic_entry(
    uint8_t *buffer,
    size_t capacity,
    const ldfs_bulk_entry *seed,
    attribute_set_t *returned_out
) {
    if (!buffer || !seed || !returned_out || capacity < sizeof(attribute_set_t)) {
        return 0;
    }

    memset(returned_out, 0, sizeof(*returned_out));
    returned_out->commonattr =
        ATTR_CMN_ERROR |
        ATTR_CMN_NAME |
        ATTR_CMN_OBJTYPE |
        ATTR_CMN_FILEID |
        ATTR_CMN_FLAGS |
        ATTR_CMN_DEVID;
    returned_out->fileattr = ATTR_FILE_DATALENGTH | ATTR_FILE_DATAALLOCSIZE;
    returned_out->forkattr =
        ATTR_CMNEXT_REALFSID |
        ATTR_CMNEXT_CLONEID |
        ATTR_CMNEXT_CLONE_REFCNT;

    size_t offset = 0;
    offset = ldfs_bulk_append(buffer, offset, capacity, returned_out, sizeof(attribute_set_t));
    if (offset == 0) {
        return 0;
    }

    uint32_t error = seed->error;
    offset = ldfs_bulk_append(buffer, offset, capacity, &error, sizeof(error));
    if (offset == 0) {
        return 0;
    }

    size_t name_len = strlen(seed->name);
    if (name_len >= sizeof(seed->name)) {
        return 0;
    }
    uint32_t name_length = (uint32_t)name_len;
    offset = ldfs_bulk_append(buffer, offset, capacity, &name_length, sizeof(name_length));
    offset = ldfs_bulk_append(buffer, offset, capacity, seed->name, name_length);
    if (offset == 0) {
        return 0;
    }

    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->obj_type, sizeof(seed->obj_type));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->file_id, sizeof(seed->file_id));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->flags, sizeof(seed->flags));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->dev, sizeof(seed->dev));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->data_length, sizeof(seed->data_length));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->alloc_size, sizeof(seed->alloc_size));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->fsid, sizeof(seed->fsid));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->clone_id, sizeof(seed->clone_id));
    offset = ldfs_bulk_append(buffer, offset, capacity, &seed->clone_refcnt, sizeof(seed->clone_refcnt));
    return offset == 0 ? 0 : offset;
}

void ldfs_bulk_request_attrlist(struct attrlist *attr_list, int use_physical_size) {
    memset(attr_list, 0, sizeof(*attr_list));
    attr_list->bitmapcount = ATTR_BIT_MAP_COUNT;
    attr_list->commonattr =
        ATTR_CMN_RETURNED_ATTRS |
        ATTR_CMN_ERROR |
        ATTR_CMN_NAME |
        ATTR_CMN_OBJTYPE |
        ATTR_CMN_FILEID |
        ATTR_CMN_FLAGS |
        ATTR_CMN_DEVID;
    attr_list->fileattr = ATTR_FILE_DATALENGTH | ATTR_FILE_DATAALLOCSIZE;
    attr_list->forkattr =
        ATTR_CMNEXT_NOFIRMLINKPATH |
        ATTR_CMNEXT_REALFSID |
        ATTR_CMNEXT_LINKID |
        ATTR_CMNEXT_CLONEID |
        ATTR_CMNEXT_CLONE_REFCNT;
}

uint32_t ldfs_bulk_options(int use_physical_size) {
    uint32_t options = FSOPT_ATTR_CMN_EXTENDED;
    if (use_physical_size) {
        options |= FSOPT_REPORT_FULLSIZE;
    }
    return options;
}

int ldfs_bulk_parse_entry(char **cursor, const char *buffer_end, const attribute_set_t *returned, ldfs_bulk_entry *out) {
    if (!cursor || !*cursor || !buffer_end || !returned || !out) {
        return -1;
    }

    memset(out, 0, sizeof(*out));
    char *field = *cursor;

    if (returned->commonattr & ATTR_CMN_RETURNED_ATTRS) {
        field = ldfs_bulk_advance(field, sizeof(attribute_set_t), buffer_end);
        if (!field) {
            return -1;
        }
    }

    if (returned->commonattr & ATTR_CMN_ERROR) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->error), buffer_end)) {
            return -1;
        }
        memcpy(&out->error, field, sizeof(out->error));
        field += sizeof(out->error);
    }

    if (returned->commonattr & ATTR_CMN_NAME) {
        if (!ldfs_bulk_field_fits(field, sizeof(uint32_t), buffer_end)) {
            return -1;
        }
        uint32_t name_length = 0;
        memcpy(&name_length, field, sizeof(name_length));
        field += sizeof(name_length);
        if (!ldfs_bulk_field_fits(field, name_length, buffer_end)) {
            return -1;
        }
        if (name_length > 0 && name_length < sizeof(out->name)) {
            memcpy(out->name, field, name_length);
            out->name[name_length] = '\0';
        }
        field += name_length;
    }

    if (returned->commonattr & ATTR_CMN_OBJTYPE) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->obj_type), buffer_end)) {
            return -1;
        }
        memcpy(&out->obj_type, field, sizeof(out->obj_type));
        field += sizeof(out->obj_type);
    }

    if (returned->commonattr & ATTR_CMN_FILEID) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->file_id), buffer_end)) {
            return -1;
        }
        memcpy(&out->file_id, field, sizeof(out->file_id));
        field += sizeof(out->file_id);
    }

    if (returned->commonattr & ATTR_CMN_FLAGS) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->flags), buffer_end)) {
            return -1;
        }
        memcpy(&out->flags, field, sizeof(out->flags));
        field += sizeof(out->flags);
    }

    if (returned->commonattr & ATTR_CMN_DEVID) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->dev), buffer_end)) {
            return -1;
        }
        memcpy(&out->dev, field, sizeof(out->dev));
        field += sizeof(out->dev);
    }

    if (returned->fileattr & ATTR_FILE_DATALENGTH) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->data_length), buffer_end)) {
            return -1;
        }
        memcpy(&out->data_length, field, sizeof(out->data_length));
        field += sizeof(out->data_length);
    }

    if (returned->fileattr & ATTR_FILE_DATAALLOCSIZE) {
        if (!ldfs_bulk_field_fits(field, sizeof(out->alloc_size), buffer_end)) {
            return -1;
        }
        memcpy(&out->alloc_size, field, sizeof(out->alloc_size));
        field += sizeof(out->alloc_size);
    }

    field = ldfs_bulk_consume_cmnext(field, buffer_end, returned->forkattr, out);
    if (!field) {
        return -1;
    }

    *cursor = field;
    return 0;
}
