/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2025                                               */
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

#include "make_machdep_common.h"
#include <stddef.h>

#define TEST_MAX_ALIGN_T_IS(type) \
    _Static_assert(ALIGNOF(max_align_t) != ALIGNOF(type), \
                   "max_align_t is `"#type"`");

TEST_MAX_ALIGN_T_IS(char)
TEST_MAX_ALIGN_T_IS(short)
TEST_MAX_ALIGN_T_IS(int)
TEST_MAX_ALIGN_T_IS(long)
TEST_MAX_ALIGN_T_IS(long long)
TEST_MAX_ALIGN_T_IS(double)
TEST_MAX_ALIGN_T_IS(long double)
TEST_MAX_ALIGN_T_IS(struct {int __max_align; } __attribute__ ((aligned (8))))
TEST_MAX_ALIGN_T_IS(struct {int __max_align; } __attribute__ ((aligned (16))))
