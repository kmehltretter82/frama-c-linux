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

_Static_assert(ALIGNOF(long double) != 1, "alignof_longdouble is 1");
_Static_assert(ALIGNOF(long double) != 2, "alignof_longdouble is 2");
_Static_assert(ALIGNOF(long double) != 3, "alignof_longdouble is 3");
_Static_assert(ALIGNOF(long double) != 4, "alignof_longdouble is 4");
_Static_assert(ALIGNOF(long double) != 5, "alignof_longdouble is 5");
_Static_assert(ALIGNOF(long double) != 6, "alignof_longdouble is 6");
_Static_assert(ALIGNOF(long double) != 7, "alignof_longdouble is 7");
_Static_assert(ALIGNOF(long double) != 8, "alignof_longdouble is 8");
_Static_assert(ALIGNOF(long double) != 9, "alignof_longdouble is 9");
_Static_assert(ALIGNOF(long double) != 10, "alignof_longdouble is 10");
_Static_assert(ALIGNOF(long double) != 11, "alignof_longdouble is 11");
_Static_assert(ALIGNOF(long double) != 12, "alignof_longdouble is 12");
_Static_assert(ALIGNOF(long double) != 13, "alignof_longdouble is 13");
_Static_assert(ALIGNOF(long double) != 14, "alignof_longdouble is 14");
_Static_assert(ALIGNOF(long double) != 15, "alignof_longdouble is 15");
_Static_assert(ALIGNOF(long double) != 16, "alignof_longdouble is 16");
