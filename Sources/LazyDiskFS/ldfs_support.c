#include "ldfs_internal.h"
#include "ldfs_bulk.h" /* include/ */

#include <sys/mount.h>

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/attr.h>
#include <sys/stat.h>
#include <sys/vnode.h>
#include <unistd.h>

typedef struct {
    char *data;
    size_t capacity;
} ldfs_tls_buffer;

static pthread_key_t ldfs_buffer_key;
static pthread_once_t ldfs_buffer_once = PTHREAD_ONCE_INIT;

static void ldfs_tls_buffer_destroy(void *ptr) {
    ldfs_tls_buffer *buffer = (ldfs_tls_buffer *)ptr;
    if (!buffer) {
        return;
    }
    free(buffer->data);
    free(buffer);
}

static void ldfs_tls_buffer_init_once(void) {
    pthread_key_create(&ldfs_buffer_key, ldfs_tls_buffer_destroy);
}

char *ldfs_thread_buffer(size_t needed) {
    pthread_once(&ldfs_buffer_once, ldfs_tls_buffer_init_once);
    ldfs_tls_buffer *buffer = (ldfs_tls_buffer *)pthread_getspecific(ldfs_buffer_key);
    if (!buffer) {
        buffer = calloc(1, sizeof(ldfs_tls_buffer));
        if (!buffer) {
            return NULL;
        }
        pthread_setspecific(ldfs_buffer_key, buffer);
    }
    if (buffer->capacity < needed) {
        char *grown = realloc(buffer->data, needed);
        if (!grown) {
            return NULL;
        }
        buffer->data = grown;
        buffer->capacity = needed;
    }
    return buffer->data;
}

size_t ldfs_effective_buffer_size(size_t requested) {
    if (requested >= LDFS_TURBO_BUFFER) {
        return LDFS_TURBO_BUFFER;
    }
    if (requested > 0) {
        return requested;
    }
    return LDFS_DEFAULT_BUFFER;
}

int ldfs_effective_worker_count(int requested, bool turbo) {
    if (requested > 0) {
        int count = requested;
        if (count > LDFS_MAX_WORKERS) {
            count = LDFS_MAX_WORKERS;
        }
        if (count < 1) {
            count = 1;
        }
        return count;
    }
    int count = turbo ? LDFS_TURBO_WORKERS : LDFS_DEFAULT_WORKERS;
    if (turbo && count < LDFS_TURBO_WORKERS) {
        count = LDFS_TURBO_WORKERS;
    }
    if (count > LDFS_MAX_WORKERS) {
        count = LDFS_MAX_WORKERS;
    }
    if (count < 1) {
        count = 1;
    }
    return count;
}

void ldfs_work_queue_init(ldfs_work_queue *queue) {
    queue->items = NULL;
    queue->head = 0;
    queue->tail = 0;
    queue->capacity = 0;
    queue->inflight = 0;
    queue->closed = 0;
    pthread_mutex_init(&queue->lock, NULL);
    pthread_cond_init(&queue->cond, NULL);
}

void ldfs_work_queue_free(ldfs_work_queue *queue) {
    if (queue->items) {
        for (size_t i = queue->head; i < queue->tail; i++) {
            free(queue->items[i].path);
            if (queue->items[i].dirfd >= 0) {
                close(queue->items[i].dirfd);
            }
        }
    }
    free(queue->items);
    pthread_mutex_destroy(&queue->lock);
    pthread_cond_destroy(&queue->cond);
}

static int ldfs_work_queue_grow(ldfs_work_queue *queue) {
    size_t new_cap = queue->capacity == 0 ? 128 : queue->capacity * 2;
    ldfs_queue_item *new_items = calloc(new_cap, sizeof(ldfs_queue_item));
    if (!new_items) {
        return -1;
    }
    size_t used = queue->tail - queue->head;
    if (queue->items && queue->capacity > 0) {
        for (size_t i = 0; i < used; i++) {
            new_items[i] = queue->items[queue->head + i];
        }
    }
    free(queue->items);
    queue->items = new_items;
    queue->head = 0;
    queue->tail = used;
    queue->capacity = new_cap;
    return 0;
}

int ldfs_work_queue_push_owned(ldfs_work_queue *queue, char *path, int dirfd) {
    pthread_mutex_lock(&queue->lock);
    if (queue->tail - queue->head >= queue->capacity) {
        if (ldfs_work_queue_grow(queue) != 0) {
            pthread_mutex_unlock(&queue->lock);
            free(path);
            return -1;
        }
    }
    queue->items[queue->tail].path = path;
    queue->items[queue->tail].dirfd = dirfd;
    queue->tail += 1;
    pthread_cond_signal(&queue->cond);
    pthread_mutex_unlock(&queue->lock);
    return 0;
}

int ldfs_work_queue_push_fd(ldfs_work_queue *queue, const char *path, int dirfd) {
    char *copy = strdup(path);
    if (!copy) {
        return -1;
    }
    int status = ldfs_work_queue_push_owned(queue, copy, dirfd);
    if (status != 0) {
        close(dirfd);
    }
    return status;
}

int ldfs_work_queue_push_child(
    ldfs_work_queue *queue,
    const char *parent,
    size_t parent_len,
    const char *name,
    size_t name_len,
    int dirfd
) {
    if (parent_len + 1 + name_len + 1 > PATH_MAX) {
        return -1;
    }
    char *path = malloc(parent_len + 1 + name_len + 1);
    if (!path) {
        return -1;
    }
    memcpy(path, parent, parent_len);
    path[parent_len] = '/';
    memcpy(path + parent_len + 1, name, name_len);
    path[parent_len + 1 + name_len] = '\0';
    return ldfs_work_queue_push_owned(queue, path, dirfd);
}

ldfs_queue_item ldfs_work_queue_pop_wait(ldfs_work_queue *queue) {
    ldfs_queue_item empty = {NULL, -1};
    pthread_mutex_lock(&queue->lock);
    while (queue->head >= queue->tail) {
        if (queue->closed) {
            pthread_mutex_unlock(&queue->lock);
            return empty;
        }
        pthread_cond_wait(&queue->cond, &queue->lock);
    }
    ldfs_queue_item item = queue->items[queue->head];
    queue->items[queue->head].path = NULL;
    queue->items[queue->head].dirfd = -1;
    queue->head += 1;
    if (queue->head == queue->tail) {
        queue->head = 0;
        queue->tail = 0;
    }
    queue->inflight += 1;
    pthread_mutex_unlock(&queue->lock);
    return item;
}

void ldfs_work_queue_finish_item(ldfs_work_queue *queue) {
    pthread_mutex_lock(&queue->lock);
    if (queue->inflight > 0) {
        queue->inflight -= 1;
    }
    if (queue->head >= queue->tail && queue->inflight == 0) {
        queue->closed = 1;
        pthread_cond_broadcast(&queue->cond);
    } else if (queue->head < queue->tail) {
        pthread_cond_signal(&queue->cond);
    }
    pthread_mutex_unlock(&queue->lock);
}

size_t ldfs_work_queue_size(ldfs_work_queue *queue) {
    pthread_mutex_lock(&queue->lock);
    size_t size = queue->tail - queue->head;
    pthread_mutex_unlock(&queue->lock);
    return size;
}

ldfs_inode_hash *ldfs_inode_hash_create(void) {
    ldfs_inode_hash *hash = calloc(1, sizeof(ldfs_inode_hash));
    if (!hash) {
        return NULL;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_init(&hash->locks[i], NULL);
    }
    return hash;
}

void ldfs_inode_hash_free(ldfs_inode_hash *hash) {
    if (!hash) {
        return;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        ldfs_inode_entry *entry = hash->buckets[i];
        while (entry) {
            ldfs_inode_entry *next = entry->next;
            free(entry);
            entry = next;
        }
        pthread_mutex_destroy(&hash->locks[i]);
    }
    free(hash);
}

ldfs_clone_hash *ldfs_clone_hash_create(void) {
    ldfs_clone_hash *hash = calloc(1, sizeof(ldfs_clone_hash));
    if (!hash) {
        return NULL;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        pthread_mutex_init(&hash->locks[i], NULL);
    }
    return hash;
}

void ldfs_clone_hash_free(ldfs_clone_hash *hash) {
    if (!hash) {
        return;
    }
    for (size_t i = 0; i < LDFS_INODE_BUCKETS; i++) {
        ldfs_clone_entry *entry = hash->buckets[i];
        while (entry) {
            ldfs_clone_entry *next = entry->next;
            free(entry);
            entry = next;
        }
        pthread_mutex_destroy(&hash->locks[i]);
    }
    free(hash);
}

bool ldfs_clone_hash_seen(ldfs_clone_hash *hash, uint64_t clone_id) {
    if (!hash || clone_id == 0) {
        return false;
    }
    size_t bucket = (clone_id >> 8) % LDFS_INODE_BUCKETS;
    pthread_mutex_lock(&hash->locks[bucket]);
    for (ldfs_clone_entry *entry = hash->buckets[bucket]; entry; entry = entry->next) {
        if (entry->clone_id == clone_id) {
            pthread_mutex_unlock(&hash->locks[bucket]);
            return true;
        }
    }
    ldfs_clone_entry *node = malloc(sizeof(ldfs_clone_entry));
    if (!node) {
        pthread_mutex_unlock(&hash->locks[bucket]);
        return false;
    }
    node->clone_id = clone_id;
    node->next = hash->buckets[bucket];
    hash->buckets[bucket] = node;
    pthread_mutex_unlock(&hash->locks[bucket]);
    return false;
}

bool ldfs_inode_hash_seen(ldfs_inode_hash *hash, uint32_t dev, uint64_t ino) {
    if (!hash || ino == 0) {
        return false;
    }
    size_t bucket = ((ino >> 8) ^ dev) % LDFS_INODE_BUCKETS;
    pthread_mutex_lock(&hash->locks[bucket]);
    for (ldfs_inode_entry *entry = hash->buckets[bucket]; entry; entry = entry->next) {
        if (entry->dev == dev && entry->ino == ino) {
            pthread_mutex_unlock(&hash->locks[bucket]);
            return true;
        }
    }
    ldfs_inode_entry *node = malloc(sizeof(ldfs_inode_entry));
    if (!node) {
        pthread_mutex_unlock(&hash->locks[bucket]);
        return false;
    }
    node->dev = dev;
    node->ino = ino;
    node->next = hash->buckets[bucket];
    hash->buckets[bucket] = node;
    pthread_mutex_unlock(&hash->locks[bucket]);
    return false;
}

