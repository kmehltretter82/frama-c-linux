/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2017                                               */
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
/*  for more details (enclosed in the file licenses/LGPLv2.1).            */
/*                                                                        */
/**************************************************************************/

/*! ***********************************************************************
 * \file  e_acsl_malloc.h
 *
 * \brief E-ACSL memory allocation bindings.
***************************************************************************/

#ifndef E_ACSL_MALLOC
#define E_ACSL_MALLOC

/* Memory allocated for internal use of RTL and for the use by the application
 * is split into to mspaces (memory spaces). Memory allocation itself is
 * delegated to a slightly cusomised version of dlmalloc shipped with the
 * RTL. The overall pattern is as follows:
 *    mspace space = create_mspace(capacity, locks);
 *    char *p = mspace_malloc(space, size); */

/* mspace stands  */
typedef void* mspace;

static struct memory_spaces {
  mspace rtl; /* `private` (RTL) mspace */
  mspace application;  /* `public` (application) mspace */
} mem_spaces;

/* While it is possible to generate prefixes using an extra level of
 * indirection with macro definitions it is probably best not to do it,
 * becomes barely readable ...*/

/* Mspace allocators {{{ */
extern mspace __e_acsl_create_mspace(size_t capacity, int locked);
extern void*  __e_acsl_mspace_malloc(mspace msp, size_t bytes);
extern void   __e_acsl_mspace_free(mspace msp, void* mem);
extern void*  __e_acsl_mspace_calloc(mspace msp, size_t n_elements, size_t elem_size);
extern void*  __e_acsl_mspace_realloc(mspace msp, void* mem, size_t newsize);
extern void*  __e_acsl_mspace_aligned_alloc(mspace msp, size_t alignment, size_t bytes);
extern int    __e_acsl_mspace_posix_memalign(mspace msp, void **memptr, size_t alignment, size_t bytes);
extern size_t __e_acsl_mspace_footprint(mspace msp);
extern size_t __e_acsl_mspace_max_footprint(mspace msp);
extern size_t __e_acsl_mspace_footprint_limit(mspace msp);

#define create_mspace          __e_acsl_create_mspace
#define mspace_malloc          __e_acsl_mspace_malloc
#define mspace_free            __e_acsl_mspace_free
#define mspace_calloc          __e_acsl_mspace_calloc
#define mspace_realloc         __e_acsl_mspace_realloc
#define mspace_posix_memalign  __e_acsl_mspace_posix_memalign
#define mspace_aligned_alloc   __e_acsl_mspace_aligned_alloc
#define mspace_footprint       __e_acsl_mspace_footprint
#define mspace_max_footprint   __e_acsl_mspace_max_footprint
#define mspace_footprint_limit __e_acsl_mspace_footprint_limit
/* }}} */

/* Public allocators used within RTL to override standard allocation {{{ */
/* Shortcuts for public allocation functions */
# define public_malloc(...)         mspace_malloc(mem_spaces.application, __VA_ARGS__)
# define public_realloc(...)        mspace_realloc(mem_spaces.application, __VA_ARGS__)
# define public_calloc(...)         mspace_calloc(mem_spaces.application, __VA_ARGS__)
# define public_free(...)           mspace_free(mem_spaces.application, __VA_ARGS__)
# define public_aligned_alloc(...)  mspace_aligned_alloc(mem_spaces.application, __VA_ARGS__)
# define public_posix_memalign(...) mspace_posix_memalign(mem_spaces.application, __VA_ARGS__)
/* }}} */

/* Private allocators usable within RTL and GMP {{{ */
void * __e_acsl_private_malloc(size_t sz) {
  return mspace_malloc(mem_spaces.rtl, sz);
}

void *__e_acsl_private_calloc(size_t nmemb, size_t sz) {
  return mspace_calloc(mem_spaces.rtl, nmemb, sz);
}

void *__e_acsl_private_realloc(void *p, size_t sz) {
  return mspace_realloc(mem_spaces.rtl, p, sz);
}

void __e_acsl_private_free(void *p) {
  mspace_free(mem_spaces.rtl, p);
}

#define private_malloc  __e_acsl_private_malloc
#define private_calloc  __e_acsl_private_calloc
#define private_realloc __e_acsl_private_realloc
#define private_free    __e_acsl_private_free
/* }}} */

/* \brief Create two memory spaces, one for RTL and the other for application
   memory. This function *SHOULD* be called before any allocations are made
   otherwise execution fails */
void make_memory_spaces(size_t rtl_size, size_t application_size) {
  mem_spaces.rtl = create_mspace(rtl_size, 0);
  mem_spaces.application = create_mspace(application_size, 0);
}

/* \return a true value if x is a power of 2 and false otherwise */
static int powof2(size_t x) {
  while (((x & 1) == 0) && x > 1) /* while x is even and > 1 */
    x >>= 1;
  return (x == 1);
}
#endif
