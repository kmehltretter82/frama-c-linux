/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2016                                               */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  you can redistribute it and/or modify it under the terms of the GNU   */
/*  Lesser General Public License as published by the Free Software       */
/*  Foundation, version 2.1.                                              */
/*                                                                        */
/*  It is distributed in the hope that it will be useful,                 */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*  GNU Lesser General Public License for more details.                   */
/*                                                                        */
/*  See the GNU Lesser General Public License version 2.1                 */
/*  for more details (enclosed in the file license/LGPLv2.1).             */
/*                                                                        */
/**************************************************************************/

/*! ***********************************************************************
 * \file   e_acsl_bittree_mmodel.c
 * \brief  Implementation of E-ACSL public API using a memory model based
 * on Patricia Trie. See e_acsl_mmodel_api.h for details.
***************************************************************************/

#ifndef E_ACSL_BITTREE_MMODEL
#define E_ACSL_BITTREE_MMODEL

#include "e_acsl_string.h"
#include "e_acsl_printf.h"
#include "e_acsl_bits.h"
#include "e_acsl_assert.h"
#include "e_acsl_debug.h"
#include "e_acsl_malloc.h"
#include "e_acsl_mmodel_api.h"
#include "e_acsl_bittree.h"

/**************************/
/* SUPPORT            {{{ */
/**************************/
static const int nbr_bits_to_1[256] = {
  0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4,1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,1,2,2,3,2,3,
  3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,1,2,2,3,2,3,3,4,2,3,3,4,
  3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,
  4,5,4,5,5,6,4,5,5,6,5,6,6,7,1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,
  3,4,4,5,4,5,5,6,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,
  6,7,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,3,4,4,5,
  4,5,5,6,4,5,5,6,5,6,6,7,4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8
};

/* given the size of the memory block (_size) return (or rather evaluate to)
 * size in bytes requred to represent its partial initialization */
#define needed_bytes(_size) \
  ((_size % 8) == 0 ? (_size/8) : (_size/8 + 1))
/* }}} */

/**************************/
/* HEAP USAGE         {{{ */
/**************************/
size_t __e_acsl_heap_size = 0;

size_t __get_memory_size(void) {
  return __e_acsl_heap_size;
}
/* }}} */

/**************************/
/* ALLOCATION         {{{ */
/**************************/

/* STACK ALLOCATION {{{ */
/* store the block of size bytes starting at ptr, the new block is returned.
 * Warning: the return type is implicitly (bt_block*). */
static void* bittree_store_block(void* ptr, size_t size) {
  bt_block * tmp;
  DASSERT(ptr != NULL);
  tmp = native_malloc(sizeof(bt_block));
  DASSERT(tmp != NULL);
  tmp->ptr = (size_t)ptr;
  tmp->size = size;
  tmp->init_ptr = NULL;
  tmp->init_bytes = 0;
  tmp->is_readonly = false;
  tmp->freeable = false;
  bt_insert(tmp);
  return tmp;
}

/* remove the block starting at ptr */
static void bittree_delete_block(void* ptr) {
  DASSERT(ptr != NULL);
  bt_block * tmp = bt_lookup(ptr);
  DASSERT(tmp != NULL);
  bt_clean_block_init(tmp);
  bt_remove(tmp);
  native_free(tmp);
}
/* }}} */

/* HEAP ALLOCATION {{{ */
/* allocate size bytes and store the returned block
 * for further information, see malloc */
static void* bittree_malloc(size_t size) {
  void * tmp;
  bt_block * new_block;
  if(size <= 0)
    return NULL;
  tmp = native_malloc(size);
  if(tmp == NULL)
    return NULL;
  new_block = __e_acsl_store_block(tmp, size);
  __e_acsl_heap_size += size;
  DASSERT(new_block != NULL && (void*)new_block->ptr != NULL);
  new_block->freeable = true;
  return (void*)new_block->ptr;
}

/* free the block starting at ptr,
 * for further information, see free */
static void bittree_free(void* ptr) {
  bt_block * tmp;
  if(ptr == NULL)
    return;
  tmp = bt_lookup(ptr);
  DASSERT(tmp != NULL);
  native_free(ptr);
  bt_clean_block_init(tmp);
  __e_acsl_heap_size -= tmp->size;
  bt_remove(tmp);
  native_free(tmp);
}

/* resize the block starting at ptr to fit its new size,
 * for further information, see realloc */
void* bittree_realloc(void* ptr, size_t size) {
  bt_block * tmp;
  void * new_ptr;
  /* ptr is NULL - malloc */
  if(ptr == NULL)
    return malloc(size);
  /* size is zero - free */
  if(size == 0) {
    free(ptr);
    return NULL;
  }
  tmp = bt_lookup(ptr);
  DASSERT(tmp != NULL);
  new_ptr = native_realloc((void*)tmp->ptr, size);
  if(new_ptr == NULL)
    return NULL;
  __e_acsl_heap_size -= tmp->size;
  /* realloc changes start address -- re-enter the element */
  if (tmp->ptr != (size_t)new_ptr) {
    bt_remove(tmp);
    tmp->ptr = (size_t)new_ptr;
    bt_insert(tmp);
  }
  /* uninitialized, do nothing */
  if(tmp->init_bytes == 0) ;
  /* already fully initialized block */
  else if (tmp->init_bytes == tmp->size) {
    /* realloc smaller block */
    if(size <= tmp->size)
      /* adjust new size, allocation not necessary */
      tmp->init_bytes = size;
    /* realloc bigger larger block */
    else {
      /* size of tmp->init_ptr in the new block  */
      int nb = needed_bytes(size);
      /* number of bits that need to be set in tmp->init_ptr */
      int nb_old = needed_bytes(tmp->size);
      /* allocate memory to store partial initialization */
      tmp->init_ptr = native_calloc(1, nb);
      /* carry out initialization of the old block */
      setbits(tmp->init_ptr, tmp->size);
    }
  }
  /* contains initialized and uninitialized parts */
  else {
    int nb = needed_bytes(size);
    int nb_old = needed_bytes(tmp->size);
    int i;
    tmp->init_ptr = native_realloc(tmp->init_ptr, nb);
    for(i = nb_old; i < nb; i++)
      tmp->init_ptr[i] = 0;
    tmp->init_bytes = 0;
    for(i = 0; i < nb; i++)
      tmp->init_bytes += nbr_bits_to_1[tmp->init_ptr[i]];
    if(tmp->init_bytes == size || tmp->init_bytes == 0) {
      native_free(tmp->init_ptr);
      tmp->init_ptr = NULL;
    }
  }
  tmp->size = size;
  tmp->freeable = true;
  __e_acsl_heap_size += size;
  return (void*)tmp->ptr;
}

/* allocate memory for an array of nbr_block elements of size_block size,
 * this memory is set to zero, the returned block is stored,
 * for further information, see calloc */
void* bittree_calloc(size_t nbr_block, size_t size_block) {
  void * tmp;
  size_t size = nbr_block * size_block;
  bt_block * new_block;
  if(size <= 0)
    return NULL;
  tmp = native_calloc(nbr_block, size_block);
  if(tmp == NULL)
    return NULL;
  new_block = __e_acsl_store_block(tmp, size);
  __e_acsl_heap_size += nbr_block * size_block;
  DASSERT(new_block != NULL && (void*)new_block->ptr != NULL);
  /* Mark allocated block as freeable and initialized */
  new_block->freeable = true;
  new_block->init_bytes = size;
  return (void*)new_block->ptr;
}
/* }}} */
/* }}} */

/**************************/
/* INITIALIZATION     {{{ */
/**************************/

/* mark the size bytes of ptr as initialized */
void __e_acsl_initialize (void * ptr, size_t size) {
  bt_block * tmp;
  if(!ptr)
    return;

  tmp = bt_find(ptr);
  if(tmp == NULL)
    return;

  /* already fully initialized, do nothing */
  if(tmp->init_bytes == tmp->size)
    return;

  /* fully uninitialized */
  if(tmp->init_bytes == 0) {
    int nb = needed_bytes(tmp->size);
    tmp->init_ptr = native_malloc(nb);
    memset(tmp->init_ptr, 0, nb);
  }

  /* partial initialization is kept via a character array accessible via the
   * tmp->init_ptr. This is such that a N-th bit of tmp->init_ptr tracks
   * initialization of the N-th byte of the memory block tracked by tmp.
   *
   * The following sets individual bits in tmp->init_ptr that track
   * initialization of `size' bytes starting from `ptr'. */
  unsigned i;
  for(i = 0; i < size; i++) {
    /* byte-offset within the block, i.e., mark `offset' byte as initialized */
    size_t offset = (uintptr_t)ptr - tmp->ptr + i;
    /* byte offset within tmp->init_ptr, i.e., a byte containing the bit to
       be toggled */
    int byte = offset/8;
    /* bit-offset within the above byte, i.e., bit to be toggled */
    int bit = offset%8;

    if (!checkbit(bit, tmp->init_ptr[byte])) { /* if bit is unset ... */
      setbit(bit, tmp->init_ptr[byte]); /* ... set the bit ... */
      tmp->init_bytes++; /* ... and increment initialized bytes count */
    }
  }

  /* now fully initialized */
  if(tmp->init_bytes == tmp->size) {
    native_free(tmp->init_ptr);
    tmp->init_ptr = NULL;
  }
}

/* mark all bytes of ptr as initialized */
void __e_acsl_full_init (void * ptr) {
  bt_block * tmp;
  if (ptr == NULL)
    return;

  tmp = bt_lookup(ptr);
  if (tmp == NULL)
    return;

  if (tmp->init_ptr != NULL) {
    native_free(tmp->init_ptr);
    tmp->init_ptr = NULL;
  }
  tmp->init_bytes = tmp->size;
}

/* mark a block as read-only */
void __e_acsl_readonly (void * ptr) {
  bt_block * tmp;
  if (ptr == NULL)
    return;
  tmp = bt_lookup(ptr);
  if (tmp == NULL)
    return;
  tmp->is_readonly = true;
}
/* }}} */

/**************************/
/* PREDICATES        {{{  */
/**************************/

int __e_acsl_freeable(void* ptr) {
  bt_block * tmp;
  if(ptr == NULL)
    return false;
  tmp = bt_lookup(ptr);
  if(tmp == NULL)
    return false;
  return tmp->freeable;
}

/* return whether the size bytes of ptr are initialized */
int __e_acsl_initialized (void * ptr, size_t size) {
  unsigned i;
  bt_block * tmp = bt_find(ptr);
  if(tmp == NULL)
    return false;

  /* fully uninitialized */
  if(tmp->init_bytes == 0)
    return false;
  /* fully initialized */
  if(tmp->init_bytes == tmp->size)
    return true;

  /* see implementation of function __e_acsl_initialize for details */
  for(i = 0; i < size; i++) {
    size_t offset = (uintptr_t)ptr - tmp->ptr + i;
    int byte = offset/8;
    int bit = offset%8;
    if (!checkbit(bit, tmp->init_ptr[byte]))
      return false;
  }
  return true;
}

/* return the length (in bytes) of the block containing ptr */
size_t __e_acsl_block_length(void* ptr) {
  bt_block * tmp = bt_find(ptr);
  /* Hard failure when un-allocated memory is used  */
  vassert(tmp != NULL, "\\block_length of unallocated memory", NULL);
  return tmp->size;
}

/* return whether the size bytes of ptr are readable/writable */
int __e_acsl_valid(void* ptr, size_t size) {
  bt_block * tmp;
  if(ptr == NULL)
    return false;
  tmp = bt_find(ptr);
  return (tmp == NULL) ?
    false : ( tmp->size - ( (size_t)ptr - tmp->ptr ) >= size
	      && !tmp->is_readonly);
}

/* return whether the size bytes of ptr are readable */
int __e_acsl_valid_read(void* ptr, size_t size) {
  bt_block * tmp;
  if(ptr == NULL)
    return false;
  tmp = bt_find(ptr);
  return (tmp == NULL) ?
    false : (tmp->size - ((size_t)ptr - tmp->ptr) >= size);
}

/* return the base address of the block containing ptr */
void* __e_acsl_base_addr(void* ptr) {
  bt_block * tmp = bt_find(ptr);
  vassert(tmp != NULL, "\\base_addr of unallocated memory", NULL);
  return (void*)tmp->ptr;
}

/* return the offset of `ptr` within its block */
int __e_acsl_offset(void* ptr) {
  bt_block * tmp = bt_find(ptr);
  vassert(tmp != NULL, "\\offset of unallocated memory", NULL);
  return ((size_t)ptr - tmp->ptr);
}
/* }}} */

/******************************/
/* PROGRAM INITIALIZATION {{{ */
/******************************/

/* erase the content of the abstract structure */
void __e_acsl_memory_clean() {
  bt_clean();
}

/* add `argv` to the memory model */
static void __init_argv(int argc, char **argv) {
  int i;

  __e_acsl_store_block(argv, (argc+1)*sizeof(char*));
  __e_acsl_full_init(argv);

  for (i = 0; i < argc; i++) {
    __e_acsl_store_block(argv[i], strlen(argv[i])+1);
    __e_acsl_full_init(argv[i]);
  }
}

void __e_acsl_memory_init(int *argc_ref, char ***argv_ref, size_t ptr_size) {
  arch_assert(ptr_size);
  if (argc_ref)
    __init_argv(*argc_ref, *argv_ref);
}
/* }}} */

/*************************/
/* DEBUG             {{{ */
/*************************/
#ifdef E_ACSL_DEBUG
/*! \brief print the information about a tracked block */
void __e_acsl_print_block (bt_block * ptr) {
  bt_print_block(ptr);
}

/*! \brief print the content of the bittree */
void __e_acsl_print_bittree() {
  bt_print();
}
#endif
/* }}} */

/* ALLOCATION API BINDINGS {{{ */

strong_alias(bittree_malloc,	malloc)
strong_alias(bittree_calloc, calloc)
strong_alias(bittree_realloc, realloc)
strong_alias(bittree_free, free)
strong_alias(bittree_delete_block, __e_acsl_delete_block)
strong_alias(bittree_store_block, __e_acsl_store_block)
/* }}} */
#endif


