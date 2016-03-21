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
 * \file   e_acsl_malloc.h
 *
 * \brief E-ACSL memory allocation bindings.
***************************************************************************/

/* Should be included after
 * printf, debug and assert but before the actual code */

#include <features.h>
#include <stddef.h>

#ifndef E_ACSL_MALLOC
#define E_ACSL_MALLOC

#ifdef __GLIBC__

/* Real functions for dynamic memory allocation in Glibc */
extern void  *__libc_malloc(size_t);
extern void  *__libc_realloc(void*, size_t);
extern void  *__libc_calloc(size_t, size_t);
extern void  *__libc_memalign(size_t, size_t);
extern void   __libc_free(void*);
extern void  *__libc_valloc(size_t);

#  define native_malloc     __libc_malloc
#  define native_realloc    __libc_realloc
#  define native_calloc     __libc_calloc
#  define native_memalign   __libc_memalign
#  define native_free       __libc_free
#  define native_valloc     __libc_valloc

/* First address past end of stack  */
extern void  *__libc_stack_end;
#  define libc_stack_end __libc_stack_end

/* FIXME: Current shadowing does rely on the fact that the memory is allocated
 * using sbrk rather than mmap, this is yet another limitation that needs to
 * be addressed in the future. By default GNU malloc will allocate any memory
 * block that is larger than 128KB limit using mmap. The below code increases
 * the limit so when larger blocks are used then GNU malloc still uses sbrk.
 * This option is controlled by the M_MMAP_THRESHOLD parameter of mallopt.
 * For 32-bit systems the maximal size of the memory block allocated using sbrk
 * is 512*1024 bytes and for 64-bit is 4*1024*1024*sizeof(unsigned long).
 *
 * Do not include malloc.h: it also includes stdio.h which clashes
 * with e_acsl_printf.h. Need to make sure though that the value of
 * M_MMAP_THRESHOLD provided below does match the value defined by the
 * malloc.h header. */
int mallopt(int param, int value);
#  define M_MMAP_THRESHOLD -3
#  if __WORDSIZE == 64
#    define MALLOC_MAX  4*1024*1024*8
#  elif __WORDSIZE == 32
#    define MALLOC_MAX 512*1024
#  endif

/* Do increase malloc threshold. Should be run via initialize and after
 * report file initialization. */
void prepare_malloc() {
  if (!mallopt(M_MMAP_THRESHOLD, MALLOC_MAX))
    vabort("Cannot increase malloc threshold to %lu\n", MALLOC_MAX);
  DLOG("<<< Increased sbrk threshold to %lu bytes >>>\n", MALLOC_MAX);
}

#else
#  error "GNU Standard library not found"
#endif
#endif
