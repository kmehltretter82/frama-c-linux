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

#include <stddef.h>

#ifndef E_ACSL_MALLOC
#define E_ACSL_MALLOC

/* Define ALIASNAME as a strong alias for NAME.  */
# define strong_alias(name, aliasname) _strong_alias(name, aliasname)
# define _strong_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((alias (#name)));

/* Define ALIASNAME as a weak alias for NAME. */
# define weak_alias(name, aliasname) _weak_alias (name, aliasname)
# define _weak_alias(name, aliasname) \
  extern __typeof (name) aliasname __attribute__ ((weak, alias (#name)));

# define preconcat(x,y) x ## y
# define concat(x,y) preconcat(x,y)

/* Prefix added to all jemalloc functions, e.g., an actual jemalloc `malloc`
 * is renamed to `__e_acsl_native_malloc` */
# define native_prefix  __e_acsl_native_
# define alloc_func_def(f,...) concat(native_prefix,f)(__VA_ARGS__)
# define alloc_func_macro(f)   concat(native_prefix,f)

extern void  *alloc_func_def(malloc, size_t);
extern void  *alloc_func_def(calloc, size_t, size_t);
extern void  *alloc_func_def(realloc, void*, size_t);
extern void   alloc_func_def(free,void*);
extern int    alloc_func_def(posix_memalign, void **, size_t, size_t);

# define native_malloc     alloc_func_macro(malloc)
# define native_realloc    alloc_func_macro(realloc)
# define native_calloc     alloc_func_macro(calloc)
# define native_memalign   alloc_func_macro(posix_memalign)
# define native_free       alloc_func_macro(free)

#endif



