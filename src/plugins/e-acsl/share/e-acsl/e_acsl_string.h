/**************************************************************************/
/*                                                                        */
/*  This file is part of the Frama-C's E-ACSL plug-in.                    */
/*                                                                        */
/*  Copyright (C) 2012-2015                                               */
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

/** Replacement of system-wide <string.h> header for use with E-ACSL
 * runtime library.
 *
 * Intended use:
 *  - For the case when the sources are compiled using GCC prefer __builtin_
 *    versions of some of the string.h functions (e.g., memset). This is mostly
 *    because the GCC builtins are on average faster.  *
 *  - For the case it is not GCC system-wide versions should be used. This
 *    and the above options require E_ACSL_BUILTINS macro to be defined
 *    at compile-time.
 *  - For the case when the analysed program contains customised definitions
 *    of string.h functions use GLIBC-based implementations. */

#ifndef E_ACSL_STD_STRING
#define E_ACSL_STD_STRING
#  if defined(__GNUC__) && defined(E_ACSL_BUILTINS)
#    define memset __builtin_memset
#    define memcpy __builtin_memcpy
#    define memmove __builtin_memmove
#    define strlen __builtin_strlen
#    define strcmp __builtin_strcmp
#    define strncmp __builtin_strncmp
#  elif defined(E_ACSL_BUILTINS)
#    include <string.h>
#  else
#    include <stdlib.h>
#    include <endian.h>
#    include "glibc/pagecopy.h"
#    include "glibc/memcopy.h"
#    include "glibc/wordcopy.c"
#    include "glibc/memcpy.c"
#    include "glibc/memmove.c"
#    include "glibc/memset.c"
#    include "glibc/strlen.c"
#    include "glibc/strcmp.c"
#    include "glibc/strncmp.c"
#  endif
#endif
