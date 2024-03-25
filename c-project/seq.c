/**
 * DYNAMIC SEQUENCE LIBRARY
 * By Tomasz Zając <tz448580@students.mimuw.edu.pl>
 * Date: 25.04.2023
 *
 * Implementation of dynamic library of sequences containing characters {0, 1, 2}.
 * Data is stored in a ternary tree, where node->sons[i] represents sequence
 * from node with additional 'i' at the end. A sequence is uniformly determined
 * by its position in a ternary tree, so a node doesn't need to contain its sequence
 * as a char * type;
 * Single node points to its equivalence class (represented with char *) and its
 * predecessor and successor in this class - a class is simply a linked list.
 * Every auxiliary function has been marked as static.
 */

#include "seq.h"
#include <assert.h>
#include <errno.h>
#include <malloc.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

/** DEFINITIONS **/

#define SONS 3

/** DATA STRUCTURES **/

// Ternary tree implementation of a set of sequences.
struct seq {
    struct seq *sons[3];        // pointers to sequences extended with '0', '1' or '2' (as follows)
    struct seq *prev;           // pointer to a predecessor in an equivalence class
    struct seq *next;           // pointer to a successor in an equivalence class
    char *class_name;           // equivalence class that this sequence represents
};

typedef struct seq seq_t;


/** FUNCTIONS **/

// Creates new empty set of sequences. It's also used to create a new node.
seq_t * seq_new(void) {

    // Memory allocation:
    seq_t *new_node = (seq_t *) malloc (sizeof(struct seq));

    // In case allocation is impossible:
    if(new_node == NULL) {
        errno = ENOMEM;
        return NULL;
    }

    // Setting parameters;
    new_node->next = NULL;
    new_node->prev = NULL;
    for(int i = 0; i < SONS; i++) {
        new_node->sons[i] = NULL;
    }
    new_node->class_name = NULL;

    return new_node;
}

// Deletes a set of sequences pointed by *p and frees the memory used by this set.
void seq_delete(seq_t *p) {
    if(p != NULL) {
        for(int i = 0; i < SONS; i++) {
            seq_delete(p->sons[i]);
            p->sons[i] = NULL;
        }
        // One-element class:
        if(p->prev == NULL && p->next == NULL) {
            free(p->class_name);
            p->class_name = NULL;
            free(p);
            p = NULL;
        }
        // Class has >1 elements:
        else if(p->prev == NULL && p->next != NULL) {
            p->next->prev = NULL;
            free(p);
        } else if(p->prev != NULL && p->next == NULL) {
            p->prev->next = NULL;
            free(p);
        } else {
            p->next->prev = p->prev;
            p->prev->next = p->next;
            free(p);
        }
    }
}

// Auxiliary: compares two strings pointed by *s1 and *s2.
static bool identical_strings(const char *s1, const char *s2) {
    if(s1 == NULL || s2 == NULL) {
        return false;
    }

    if((int) strlen(s1) != (int) strlen(s2)) {
        return false;
    }

    for(int i = 0; i < (int) strlen(s1); i++) {
        if(s1[i] != s2[i]) {
            return false;
        }
    }

    return true;
}

// Auxiliary: checks if a sequence only contains characters '0', '1' and '2'.
static bool only_012(char const *s) {
    assert(s != NULL);
    bool ok = true;
    int s_len = (int) strlen(s);
    int i = 0;
    while(ok && i < s_len) {
        if(s[i] != '0' && s[i] != '1' && s[i] != '2') {
            ok = false;
        }
        i++;
    }
    return ok;
}

// Auxiliary: checks if given array is a proper string.
static bool is_string(char const *s) {
    return *s != '\0';
}

// Adds a sequence *s and all its prefixes to a set pointed by *p.
int seq_add(seq_t *p, char const *s) {

    // In case a parameter is invalid:
    if (p == NULL || s == NULL || !only_012(s) || !is_string(s)) {
        errno = EINVAL;
        return -1;
    }

    seq_t *node = p;
    assert(node != NULL);
    seq_t *zero_added_node = NULL;
    seq_t *first_added_node = NULL;
    int index = 0;
    int s_len = (int) strlen(s);
    bool alloc_fail = false;

    // This loop starts with *node pointing to the root *p
    while (index < s_len && !alloc_fail) {

        int son_index = (int) (s[index] - '0');

        if (node->sons[son_index] == NULL) {
            node->sons[son_index] = seq_new();

            // If allocation fails after adding some nodes, we remove
            // all added nodes starting with first_added_node:
            if (node->sons[son_index] == NULL) {
                alloc_fail = true;
                errno = ENOMEM;
                if(zero_added_node != NULL) {
                    if(zero_added_node->sons[0] == first_added_node) {
                        zero_added_node->sons[0] = NULL;
                    } else if(zero_added_node->sons[1] == first_added_node) {
                        zero_added_node->sons[1] = NULL;
                    } else {
                        zero_added_node->sons[2] = NULL;
                    }
                }
                seq_delete(first_added_node);

            } else if (first_added_node == NULL) {
                zero_added_node = node;
                first_added_node = node->sons[son_index];
            }
        }

        node = node->sons[son_index];
        index++;
    }

    if(alloc_fail) {
        return -1;
    }
    if(first_added_node == NULL) {
        return 0;
    }
    return 1;
}

// Auxiliary: gives a pointer to a node containing sequence *s,
// returns NULL if *s does not belong to the set *p.
static seq_t * give_seq_pointer(seq_t *p, char const *s) {

    if (p != NULL && s != NULL && only_012(s) && is_string(s)) {
        seq_t *node = p;
        int s_len = (int) strlen(s);
        int index = 0;

        while(node != NULL && index < s_len) {
            int son_index = (int) (s[index] - '0');
            node = node->sons[son_index];
            index++;
        }
        return node;
    } else {
        return NULL;
    }
}

// Auxiliary: similar to give_seq_pointer, but for a given sequence
// returns a pointer to the parent node.
static seq_t * give_parent_pointer(seq_t *p, char const *s) {

    if (p != NULL && s != NULL && only_012(s) && is_string(s)) {
        seq_t *node = p;
        int s_len = (int) strlen(s);
        int index = 0;

        while(node != NULL && index < s_len - 1) {
            int son_index = (int) (s[index] - '0');
            node = node->sons[son_index];
            index++;
        }
        return node;
    } else {
        return NULL;
    }

}

// Removes a sequence *s and all sequences of a type s*A, where A
// is also a non-empty sequence, from the structure pointed by *p.
int seq_remove(seq_t *p, char const *s) {

    if (p == NULL || s == NULL || !only_012(s) || !is_string(s)) {
        errno = EINVAL;
        return -1;
    }

    // Getting pointers to the node with sequence s and its parent:
    int s_len = (int) strlen(s);
    if(s_len == 1) {
        seq_t *node_to_remove = give_seq_pointer(p, s);
        p->sons[(int) s[0] - '\0'] = NULL;
        seq_delete(node_to_remove);
        return 1;
    } else {
        seq_t *parent_node = give_parent_pointer(p, s);
        seq_t *node_to_remove = give_seq_pointer(p, s);

        if(parent_node == NULL || node_to_remove == NULL) {
            return 0;
        } else {
            if(parent_node->sons[0] == node_to_remove) {
                parent_node->sons[0] = NULL;
            } else if(parent_node->sons[1] == node_to_remove) {
                parent_node->sons[1] = NULL;
            } else if(parent_node->sons[2] == node_to_remove){
                parent_node->sons[2] = NULL;
            }
            seq_delete(node_to_remove);
            return 1;
        }
    }
}

// Checks if a sequence *s belongs to a set *p.
int seq_valid(seq_t *p, char const *s) {

    if (p == NULL || s == NULL || !only_012(s) || !is_string(s)) {
        errno = EINVAL;
        return -1;
    }

    seq_t *node_to_check = give_seq_pointer(p, s);

    return node_to_check != NULL;
}

// Sets or changes the name of an equivalence class of given sequence.
int seq_set_name(seq_t *p, char const *s, char const *n) {

    if (p == NULL || s == NULL || n == NULL || !only_012(s) || !is_string(s) || !is_string(n)) {
        errno = EINVAL;
        return -1;
    }

    seq_t *node = give_seq_pointer(p, s);
    if(node != NULL) {
        if(node->class_name != NULL) {
            if(identical_strings(node->class_name, n)) {
                return 0;
            }
        }
    } else {
        return 0;
    }

    // Making a copy of the new name:
    int n_len = (int) strlen(n);
    char *new_name = (char*) malloc((n_len + 1) * sizeof(char));
    if(new_name == NULL) {
        errno = ENOMEM;
        return -1;
    }
    int i = 0;
    while(i < n_len) {
        new_name[i] = n[i];
        i++;
    }
    new_name[i] = '\0';

    // If nothing had been set before:
    if(node->class_name == NULL) {
        while(node->prev != NULL) {
            node = node->prev;
        }
        while(node != NULL) {
            node->class_name = new_name;
            node = node->next;
        }
        return 1;
    }
    // If name has to be overwritten:
    else if(!(identical_strings(node->class_name, new_name))) {
        char * name_to_remove = node->class_name;
        while(node->prev != NULL) {
            node = node->prev;
        }
        while(node != NULL) {
            node->class_name = new_name;
            node = node->next;
        }
        free(name_to_remove);
        return 1;
    }
    return 0;
}

// Returns pointer to the name of an equivalence class of given sequence.
char const * seq_get_name(seq_t *p, char const *s) {

    if (p == NULL || s == NULL || !only_012(s) || !is_string(s)) {
        errno = EINVAL;
        return NULL;
    }

    seq_t *node = give_seq_pointer(p, s);

    // "Lazy" calculation prevents segfault:
    if(node == NULL || node->class_name == NULL) {
        errno = 0;
        return NULL;
    } else {
        return node->class_name;
    }

}

// Merges two equivalence classes of given sequences into one class,
// which name is a concatenation of these classes' names.
// Apologies: this function is long, because it was being repaired
// minutes before the deadline, and finally worked. I'll be thankful
// if you take it into consideration. :)
int seq_equiv(seq_t *p, char const *s1, char const *s2) {

    if (p == NULL || s1 == NULL || s2 == NULL || !only_012(s1) ||
    !only_012(s2) || !is_string(s1) || !is_string(s2)) {
        errno = EINVAL;
        return -1;
    }

    // Variables:
    seq_t *node1 = give_seq_pointer(p, s1);
    seq_t *node2 = give_seq_pointer(p, s2);

    if(node1 == NULL || node2 == NULL || node1 == node2 || (node1->class_name != NULL &&
    node2->class_name != NULL && node1->class_name == node2->class_name)) {
        return 0;
    }

    char *name1 = node1->class_name;
    char *name2 = node2->class_name;

    // Linking beginnings and endings of classes:
    seq_t * ending1 = node1;
    while(ending1->next != NULL) {
        ending1 = ending1->next;
    }
    seq_t *beginning2 = node2;
    while(beginning2->prev != NULL) {
        beginning2 = beginning2->prev;
    }
    ending1->next = beginning2;
    beginning2->prev = ending1;

    seq_t *class_beginning = ending1;
    while(class_beginning->prev != NULL) {
        class_beginning = class_beginning->prev;
    }

    // Setting the name:
    if(name1 == NULL && name2 == NULL) {
        seq_t *node = class_beginning;
        while(node != NULL) {
            node->class_name = NULL;
            node = node->next;
        }
    } else if(name1 == NULL && name2 != NULL) {
        char *new_name = name2;
        seq_t *node = class_beginning;
        while (node != NULL) {
            node->class_name = new_name;
            node = node->next;
        }
    } else if(name1 != NULL && name2 == NULL) {
        char *new_name = name1;
        seq_t *node = class_beginning;
        while(node != NULL) {
            node->class_name = new_name;
            node = node->next;
        }
    } else {
        if(!(identical_strings(name1, name2))) {
            int new_name_size = (int) strlen(name1) + (int) strlen(name2) + 1;
            char *new_name = (char *) malloc(new_name_size * sizeof(char));
            if (new_name == NULL) {
                errno = ENOMEM;
                return -1;
            }
            int position = 0;
            int i = 0;
            while(i < (int) strlen(name1)) {
                new_name[position] = name1[i];
                position++;
                i++;
            }
            i = 0;
            while(i < (int) strlen(name2)) {
                new_name[position] = name2[i];
                position++;
                i++;
            }
            new_name[position] = '\0';
            char *name1_to_remove = name1;
            char *name2_to_remove = name2;
            seq_t *node = class_beginning;
            while(node != NULL) {
                node->class_name = new_name;
                node = node->next;
            }
            free(name1_to_remove);
            free(name2_to_remove);
        } else {
            char *new_name = name1;
            char *name_to_remove = name2;
            seq_t *node = class_beginning;
            while(node != NULL) {
                node->class_name = new_name;
                node = node->next;
            }
            free(name_to_remove);
        }
    }
    return 1;
}
