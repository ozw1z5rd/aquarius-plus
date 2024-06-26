#include "symbols.h"

struct entry {
    struct entry *next;
    uint16_t      value;
    uint16_t      scope;
    uint8_t       name_len;
    char          name[];
};

static struct entry *hash_table[128];
static uint8_t       name_len;
static uint8_t       hash_idx;
static struct entry *cur_entry;

static void hash(const char *str, uint8_t len, bool check_scope) {
    hash_idx      = 0;
    name_len      = len;
    cur_entry     = NULL;
    const char *p = str;

    if (name_len == 0) {
        while (*p) {
            hash_idx += *(p++);
            name_len++;
        }
    } else {
        while (len--) {
            hash_idx += *(p++);
        }
    }
    hash_idx &= 127;

    cur_entry = hash_table[hash_idx];
    while (cur_entry) {
        if (cur_entry->name_len == name_len && memcmp(cur_entry->name, str, name_len) == 0 &&
            (!check_scope || cur_entry->scope == cur_scope))
            return;
        cur_entry = cur_entry->next;
    }
}

struct entry *alloc_entry(void) {
    return malloc(sizeof(struct entry) + name_len);
}

void symbol_add(const char *str, size_t len, uint16_t value) {
    if (str[0] != '.')
        cur_scope++;

    if (cur_pass > 0)
        return;

    hash(str, len, str[0] == '.');
    if (cur_entry) {
        if (cur_entry->value == value)
            return;
        error("Symbol already exists");
    }

    struct entry *new_entry = alloc_entry();
    new_entry->next         = hash_table[hash_idx];
    new_entry->value        = value;
    new_entry->scope        = cur_scope;
    new_entry->name_len     = name_len;
    memcpy(new_entry->name, str, name_len);
    hash_table[hash_idx] = new_entry;

#if 0
    printf("[Add symbol %.*s = $%04x  hash: %u]\n", (int)name_len, str, value, hash_idx);
#endif
}

uint16_t symbol_get(const char *str, size_t len, bool allow_undefined) {
    hash(str, len, str[0] == '.');
    if (!cur_entry) {
        if (allow_undefined)
            return 0;
        else {
#if 0
            printf("'%s'\n", str);
#endif
            error("Symbol not found");
        }
    }
    return cur_entry->value;
}
