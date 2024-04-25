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

#include "make_machdep_common.h"

_Static_assert(ALIGNOF("test string") != 1, "alignof_str is 1");
_Static_assert(ALIGNOF("test string") != 2, "alignof_str is 2");
_Static_assert(ALIGNOF("test string") != 3, "alignof_str is 3");
_Static_assert(ALIGNOF("test string") != 4, "alignof_str is 4");
_Static_assert(ALIGNOF("test string") != 5, "alignof_str is 5");
_Static_assert(ALIGNOF("test string") != 6, "alignof_str is 6");
_Static_assert(ALIGNOF("test string") != 7, "alignof_str is 7");
_Static_assert(ALIGNOF("test string") != 8, "alignof_str is 8");
