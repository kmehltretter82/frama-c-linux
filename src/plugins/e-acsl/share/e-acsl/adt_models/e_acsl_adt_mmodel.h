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

#ifndef E_ACSL_ADT_MMODEL
#define E_ACSL_ADT_MMODEL

#include "e_acsl_string.h"
#include "e_acsl_printf.h"
#include "e_acsl_bits.h"
#include "e_acsl_assert.h"
#include "e_acsl_debug.h"
#include "e_acsl_malloc.h"
#include "e_acsl_mmodel_api.h"
#include "e_acsl_adt_api.h"

size_t __heap_size = 0;

static const int nbr_bits_to_1[256] = {
  0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4,1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,1,2,2,3,2,3,
  3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,1,2,2,3,2,3,3,4,2,3,3,4,
  3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,
  4,5,4,5,5,6,4,5,5,6,5,6,6,7,1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,
  3,4,4,5,4,5,5,6,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,
  6,7,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,3,4,4,5,
  4,5,5,6,4,5,5,6,5,6,6,7,4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8
};

/*@ assigns \nothing;
  @ ensures \result == __heap_size;
  @*/
size_t __get_memory_size(void) {
  return __heap_size;
}

/*@ assigns \nothing;
  @ ensures size%8 == 0 ==> \result == size/8;
  @ ensures size%8 != 0 ==> \result == size/8+1;
  @*/
static size_t needed_bytes (size_t size) {
  return (size % 8) == 0 ? (size/8) : (size/8 + 1);
}

/* store the block of size bytes starting at ptr, the new block is returned.
 * Warning: the return type is implicitly (struct _block*). */
void* __store_block(void* ptr, size_t size) {
  struct _block * tmp;
  DASSERT(ptr != NULL);
  tmp = native_malloc(sizeof(struct _block));
  DASSERT(tmp != NULL);
  tmp->ptr = (size_t)ptr;
  tmp->size = size;
  tmp->init_ptr = NULL;
  tmp->init_cpt = 0;
  tmp->is_readonly = false;
  tmp->freeable = false;
  __add_element(tmp);
  return tmp;
}

/* remove the block starting at ptr */
void __delete_block(void* ptr) {
  struct _block * tmp = __get_exact(ptr);
  DASSERT(tmp != NULL);
  __clean_init(tmp);
  __remove_element(tmp);
  native_free(tmp);
}

/* allocate size bytes and store the returned block
 * for further information, see malloc */
void* __malloc(size_t size) {
  void * tmp;
  struct _block * new_block;
  if(size <= 0)
    return NULL;
  tmp = native_malloc(size);
  if(tmp == NULL)
    return NULL;
  new_block = __store_block(tmp, size);
  __heap_size += size;
  DASSERT(new_block != NULL && (void*)new_block->ptr != NULL);
  new_block->freeable = true;
  return (void*)new_block->ptr;
}

/* free the block starting at ptr,
 * for further information, see free */
void __free(void* ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return;
  tmp = __get_exact(ptr);
  DASSERT(tmp != NULL);
  native_free(ptr);
  __clean_init(tmp);
  __heap_size -= tmp->size;
  __remove_element(tmp);
  native_free(tmp);
}

int __freeable(void* ptr) {
  struct _block * tmp;
  if(ptr == NULL)
    return false;
  tmp = __get_exact(ptr);
  if(tmp == NULL)
    return false;
  return tmp->freeable;
}

/* resize the block starting at ptr to fit its new size,
 * for further information, see realloc */
void* __realloc(void* ptr, size_t size) {
  struct _block * tmp;
  void * new_ptr;
  /* ptr is NULL - malloc */
  if(ptr == NULL)
    return __malloc(size);
  /* size is zero - free */
  if(size == 0) {
    __free(ptr);
    return NULL;
  }
  tmp = __get_exact(ptr);
  DASSERT(tmp != NULL);
  new_ptr = native_realloc((void*)tmp->ptr, size);
  if(new_ptr == NULL)
    return NULL;
  __heap_size -= tmp->size;
  /* realloc changes start address -- re-enter the element into the ADT */
  if (tmp->ptr != (size_t)new_ptr) {
    __remove_element(tmp);
    tmp->ptr = (size_t)new_ptr;
    __add_element(tmp);
  }
  /* uninitialized, do nothing */
  if(tmp->init_cpt == 0) ;
  /* already fully initialized block */
  else if (tmp->init_cpt == tmp->size) {
    /* realloc smaller block */
    if(size <= tmp->size)
      /* adjust new size, allocation not necessary */
      tmp->init_cpt = size;
    /* realloc bigger larger block */
    else {
      /* Since realloc increases the size of the block full initialization
       * becomes partial initialization, that is, we need to allocate
       * tmp->init_ptr and set its first `old size' bits. */

      /* Size of tmp->init_ptr in the new block  */
      int nb = needed_bytes(size);
      /* Number of bits that need to be set in tmp->init_ptr */
      int nb_old = needed_bytes(tmp->size);
      /* Allocate memory to store partial initialization */
      tmp->init_ptr = native_calloc(1, nb);
      /* Carry out initialization of the old block */
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
    tmp->init_cpt = 0;
    for(i = 0; i < nb; i++)
      tmp->init_cpt += nbr_bits_to_1[tmp->init_ptr[i]];
    if(tmp->init_cpt == size || tmp->init_cpt == 0) {
      native_free(tmp->init_ptr);
      tmp->init_ptr = NULL;
    }
  }
  tmp->size = size;
  tmp->freeable = true;
  __heap_size += size;
  return (void*)tmp->ptr;
}

/* allocate memory for an array of nbr_block elements of size_block size,
 * this memory is set to zero, the returned block is stored,
 * for further information, see calloc */
void* __calloc(size_t nbr_block, size_t size_block) {
  void * tmp;
  size_t size = nbr_block * size_block;
  struct _block * new_block;
  if(size <= 0)
    return NULL;
  tmp = native_calloc(nbr_block, size_block);
  if(tmp == NULL)
    return NULL;
  new_block = __store_block(tmp, size);
  __heap_size += nbr_block * size_block;
  DASSERT(new_block != NULL && (void*)new_block->ptr != NULL);
  /* Mark allocated block as freeable and initialized */
  new_block->freeable = true;
  new_block->init_cpt = size;
  return (void*)new_block->ptr;
}

/* mark the size bytes of ptr as initialized */
void __initialize (void * ptr, size_t size) {
  struct _block * tmp;
  if(!ptr)
    return;

  tmp = __get_cont(ptr);
  if(tmp == NULL)
    return;

  /* already fully initialized, do nothing */
  if(tmp->init_cpt == tmp->size)
    return;

  /* fully uninitialized */
  if(tmp->init_cpt == 0) {
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
      tmp->init_cpt++; /* ... and increment initialized bytes count */
    }
  }

  /* now fully initialized */
  if(tmp->init_cpt == tmp->size) {
    native_free(tmp->init_ptr);
    tmp->init_ptr = NULL;
  }
}

/* mark all bytes of ptr as initialized */
void __full_init (void * ptr) {
  struct _block * tmp;
  if (ptr == NULL)
    return;

  tmp = __get_exact(ptr);
  if (tmp == NULL)
    return;

  if (tmp->init_ptr != NULL) {
    native_free(tmp->init_ptr);
    tmp->init_ptr = NULL;
  }

  tmp->init_cpt = tmp->size;
}

/* mark a block as read-only */
void __readonly (void * ptr) {
  struct _block * tmp;
  if (ptr == NULL)
    return;
  tmp = __get_exact(ptr);
  if (tmp == NULL)
    return;
  tmp->is_readonly = true;
}

/* return whether the size bytes of ptr are initialized */
int __initialized (void * ptr, size_t size) {
  unsigned i;
  struct _block * tmp = __get_cont(ptr);
  if(tmp == NULL)
    return false;

  /* fully uninitialized */
  if(tmp->init_cpt == 0)
    return false;
  /* fully initialized */
  if(tmp->init_cpt == tmp->size)
    return true;

  /* see implementation of function __initialize for details */
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
size_t __block_length(void* ptr) {
  struct _block * tmp = __get_cont(ptr);
  /* Hard failure when un-allocated memory is used  */
  vassert(tmp != NULL, "\\block_length of unallocated memory", NULL);
  return tmp->size;
}

/* return whether the size bytes of ptr are readable/writable */
int __valid(void* ptr, size_t size) {
  struct _block * tmp;
  if(ptr == NULL)
    return false;
  tmp = __get_cont(ptr);
  return (tmp == NULL) ?
    false : ( tmp->size - ( (size_t)ptr - tmp->ptr ) >= size
	      && !tmp->is_readonly);
}

/* return whether the size bytes of ptr are readable */
int __valid_read(void* ptr, size_t size) {
  struct _block * tmp;
  if(ptr == NULL)
    return false;
  tmp = __get_cont(ptr);
  return (tmp == NULL) ?
    false : (tmp->size - ((size_t)ptr - tmp->ptr) >= size);
}

/* return the base address of the block containing ptr */
void* __base_addr(void* ptr) {
  struct _block * tmp = __get_cont(ptr);
  vassert(tmp != NULL, "\\base_addr of unallocated memory", NULL);
  return (void*)tmp->ptr;
}

/* return the offset of ptr within its block */
int __offset(void* ptr) {
  struct _block * tmp = __get_cont(ptr);
  vassert(tmp != NULL, "\\offset of unallocated memory", NULL);
  return ((size_t)ptr - tmp->ptr);
}

/********************/
/* CLEAN            */
/********************/

/* erase information about initialization of a block */
void __clean_init (struct _block * ptr) {
  if(ptr->init_ptr != NULL) {
    native_free(ptr->init_ptr);
    ptr->init_ptr = NULL;
  }
  ptr->init_cpt = 0;
}

/* erase all information about a block */
void __clean_block (struct _block * ptr) {
  if(ptr) {
    __clean_init(ptr);
    native_free(ptr);
  }
}

/* erase the content of the abstract structure */
void __e_acsl_memory_clean() {
  __clean_struct();
}

/* adds argc / argv to the memory model */
static void __init_argv(int argc, char **argv) {
  int i;

  __store_block(argv, (argc+1)*sizeof(char*));
  __full_init(argv);

  for (i = 0; i < argc; i++) {
    __store_block(argv[i], strlen(argv[i])+1);
    __full_init(argv[i]);
  }
}

/* initialize contents of the abstract structure and record arguments
 *  argc_ref address the variable holding the argc parameter
 *  argv_ref address the variable holding the argv parameter
 *  ptr_size the size of the pointer computed during instrumentation. */
void __e_acsl_memory_init(int *argc_ref, char ***argv_ref, size_t ptr_size) {
  arch_assert(ptr_size);
  if (argc_ref)
    __init_argv(*argc_ref, *argv_ref);
}

/**********************/
/* DEBUG              */
/**********************/
#ifdef E_ACSL_DEBUG

/* print the information about a block */
void __e_acsl_print_block (struct _block * ptr) {
  if (ptr != NULL) {
    DLOG("%a; %lu Bytes; %slitteral; [init] : %d ",
      (char*)ptr->ptr, ptr->size,
      ptr->is_readonly ? "" : "not ", ptr->init_cpt);
    if(ptr->init_ptr != NULL) {
      unsigned i;
      for(i = 0; i < ptr->size/8; i++)
        DLOG("%b ", ptr->init_ptr[i]);
    }
    DLOG("\n");
  }
}

static void debug_struct();

/* print the content of the abstract structure */
void __e_acsl_debug() {
  debug_struct();
}

#endif
#endif
