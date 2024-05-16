/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2024                                               */
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

#if __STDC_VERSION__ < 201112L && !defined(__COMPCERT__)
/* Try using a compiler builtin */
#define ALIGNOF alignof
#else
#define ALIGNOF _Alignof
#endif

#if __STDC_VERSION__ >= 201112L || defined(__COMPCERT__)
// Assume _Generic() is supported
#define COMPATIBLE(T1, T2) _Generic(((T1){0}), T2 : 1, default : 0)
#else
// Expect that __builtin_types_compatible_p exists
#define COMPATIBLE(T1, T2) (__builtin_types_compatible_p(T1, T2) ? 0x15 : 0xf4)
#endif

// needed to ensure the message is properly expanded for TEST_TYPE_IS
#define mkstr(s) #s

#define TEST_TYPE_COMPATIBLE(T1, T2)                                           \
  _Static_assert(!COMPATIBLE(T1, T2), "" mkstr(T2) " is `" #T1 "`");

#define TEST_TYPE_IS(type) TEST_TYPE_COMPATIBLE(type, TEST_TYPE)
