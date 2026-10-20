#include "ldfs.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/snapshot.h>
#include <unistd.h>

int ldfs_clone_reference_count(const char *path, uint32_t *out_count) {
    if (!path || !out_count) {
        return -EINVAL;
    }
    *out_count = 0;

    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_RETURNED_ATTRS;
    attrs.forkattr = ATTR_CMNEXT_CLONEID | ATTR_CMNEXT_CLONE_REFCNT;

    char buffer[512];
    memset(buffer, 0, sizeof(buffer));
    if (getattrlist(path, &attrs, buffer, sizeof(buffer), FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW) != 0) {
        return -errno;
    }

    attribute_set_t returned;
    memcpy(&returned, buffer, sizeof(returned));
    char *field = buffer + sizeof(returned);
    const char *end = buffer + sizeof(buffer);

    if (returned.commonattr & ATTR_CMN_RETURNED_ATTRS) {
        if (field + sizeof(attribute_set_t) > end) {
            return -EIO;
        }
        field += sizeof(attribute_set_t);
    }
    if (returned.forkattr & ATTR_CMNEXT_CLONEID) {
        if (field + sizeof(uint64_t) > end) {
            return -EIO;
        }
        field += sizeof(uint64_t);
    }
    if (returned.forkattr & ATTR_CMNEXT_CLONE_REFCNT) {
        if (field + sizeof(uint32_t) > end) {
            return -EIO;
        }
        uint32_t count = 0;
        memcpy(&count, field, sizeof(count));
        *out_count = count;
    }
    return 0;
}

static int snapshot_name_plausible(const char *name) {
    if (!name || name[0] == '\0') {
        return 0;
    }
    size_t length = strnlen(name, 256);
    if (length == 0 || length >= 256) {
        return 0;
    }
    for (size_t i = 0; i < length; i++) {
        unsigned char c = (unsigned char)name[i];
        if (c < 0x20 || c == 0x7f || c == '"' || c == '\\') {
            return 0;
        }
    }
    return 1;
}

typedef struct {
    char name[256];
    int64_t created_sec;
} ldfs_snap_row;

static int append_row(ldfs_snap_row *rows, size_t *count, size_t max, const char *name, int64_t created) {
    if (!snapshot_name_plausible(name) || *count >= max) {
        return 0;
    }
    for (size_t i = 0; i < *count; i++) {
        if (strncmp(rows[i].name, name, sizeof(rows[i].name)) == 0) {
            return 0;
        }
    }
    memset(&rows[*count], 0, sizeof(rows[*count]));
    strncpy(rows[*count].name, name, sizeof(rows[*count].name) - 1);
    rows[*count].created_sec = created > 0 ? created : 0;
    *count += 1;
    return 1;
}

static const char *name_from_reference(const attrreference_t *reference, const char *record_end) {
    if (!reference || reference->attr_length < 2 || reference->attr_length > 256) {
        return NULL;
    }
    const char *base = (const char *)reference;
    const char *name = base + reference->attr_dataoffset;
    if (name < base || name + reference->attr_length > record_end) {
        return NULL;
    }
    if (name[reference->attr_length - 1] != '\0') {
        return NULL;
    }
    return name;
}

static size_t parse_length_prefixed(
    const char *buffer,
    size_t capacity,
    ldfs_snap_row *rows,
    size_t max
) {
    size_t count = 0;
    size_t offset = 0;
    const size_t minimum = sizeof(uint32_t) + sizeof(attribute_set_t) + sizeof(attrreference_t);
    while (offset + minimum <= capacity && count < max) {
        uint32_t length = 0;
        memcpy(&length, buffer + offset, sizeof(length));
        if (length < minimum || length > 4096 || offset + length > capacity) {
            break;
        }
        const char *record = buffer + offset;
        const char *end = record + length;
        attribute_set_t returned;
        memcpy(&returned, record + sizeof(uint32_t), sizeof(returned));
        const char *field = record + sizeof(uint32_t) + sizeof(attribute_set_t);
        const char *name = NULL;
        int64_t created = 0;

        if ((returned.commonattr & ATTR_CMN_NAME) && field + sizeof(attrreference_t) <= end) {
            const attrreference_t *name_ref = (const attrreference_t *)field;
            name = name_from_reference(name_ref, end);
            field += sizeof(attrreference_t);
        }
        if ((returned.commonattr & ATTR_CMN_CRTIME) && field + sizeof(struct timespec) <= end) {
            struct timespec created_at;
            memcpy(&created_at, field, sizeof(created_at));
            if (created_at.tv_sec > 1000000000LL && created_at.tv_sec < 4000000000LL) {
                created = (int64_t)created_at.tv_sec;
            }
        }
        if (name) {
            append_row(rows, &count, max, name, created);
        }
        offset += length;
    }
    return count;
}

static char *rows_to_json(const ldfs_snap_row *rows, size_t count) {
    size_t capacity = 64 + count * 320;
    if (capacity < 64) {
        capacity = 64;
    }
    char *json = malloc(capacity);
    if (!json) {
        return NULL;
    }
    size_t used = 0;
    json[used++] = '[';
    for (size_t i = 0; i < count; i++) {
        int wrote = snprintf(
            json + used,
            capacity - used,
            "%s{\"name\":\"%s\",\"created\":%lld,\"bytes\":-1}",
            i == 0 ? "" : ",",
            rows[i].name,
            (long long)rows[i].created_sec
        );
        if (wrote < 0 || (size_t)wrote >= capacity - used) {
            free(json);
            return NULL;
        }
        used += (size_t)wrote;
    }
    if (used + 2 >= capacity) {
        free(json);
        return NULL;
    }
    json[used++] = ']';
    json[used] = '\0';
    return json;
}

int ldfs_list_snapshots_json(const char *volume_path, char **json_out) {
    if (!volume_path || !json_out) {
        return -EINVAL;
    }
    *json_out = NULL;

    int fd = open(volume_path, O_RDONLY | O_DIRECTORY);
    if (fd < 0) {
        *json_out = strdup("[]");
        return *json_out ? 0 : -ENOMEM;
    }

    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_NAME | ATTR_CMN_CRTIME;

    const size_t capacity = 1024 * 1024;
    char *buffer = calloc(1, capacity);
    if (!buffer) {
        close(fd);
        return -ENOMEM;
    }

    int rc = fs_snapshot_list(fd, &attrs, buffer, capacity, 0);
    close(fd);

    ldfs_snap_row rows[256];
    size_t count = 0;
    if (rc >= 0) {
        count = parse_length_prefixed(buffer, capacity, rows, 256);
    }
    free(buffer);

    char *json = rows_to_json(rows, count);
    if (!json) {
        return -ENOMEM;
    }
    *json_out = json;
    return 0;
}

int ldfs_delete_snapshot(const char *volume_path, const char *name) {
    if (!volume_path || !name || name[0] == '\0' || strchr(name, '/') != NULL) {
        return -EINVAL;
    }
    if (strncmp(name, "com.apple.os.update-", 20) == 0
        || strncmp(name, "com.apple.os.install", 20) == 0
        || strncmp(name, "com.apple.bless", 15) == 0) {
        return -EPERM;
    }
    int fd = open(volume_path, O_RDONLY | O_DIRECTORY);
    if (fd < 0) {
        return -errno;
    }
    int rc = fs_snapshot_delete(fd, name, 0);
    int error = rc == 0 ? 0 : errno;
    close(fd);
    return error == 0 ? 0 : -error;
}
