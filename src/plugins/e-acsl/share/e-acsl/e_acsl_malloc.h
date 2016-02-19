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

/**********************************/
/* Bindings for memory allocation */
/**********************************/

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

#else
#  error "GNU Standard library not found"
#endif
#endif
