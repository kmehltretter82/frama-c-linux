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

typedef char array[1] __attribute__((__aligned__));

_Static_assert(ALIGNOF(array)!=1, "alignof_aligned is 1");
_Static_assert(ALIGNOF(array)!=2, "alignof_aligned is 2");
_Static_assert(ALIGNOF(array)!=3, "alignof_aligned is 3");
_Static_assert(ALIGNOF(array)!=4, "alignof_aligned is 4");
_Static_assert(ALIGNOF(array)!=5, "alignof_aligned is 5");
_Static_assert(ALIGNOF(array)!=6, "alignof_aligned is 6");
_Static_assert(ALIGNOF(array)!=7, "alignof_aligned is 7");
_Static_assert(ALIGNOF(array)!=8, "alignof_aligned is 8");
_Static_assert(ALIGNOF(array)!=9, "alignof_aligned is 9");
_Static_assert(ALIGNOF(array)!=10, "alignof_aligned is 10");
_Static_assert(ALIGNOF(array)!=11, "alignof_aligned is 11");
_Static_assert(ALIGNOF(array)!=12, "alignof_aligned is 12");
_Static_assert(ALIGNOF(array)!=13, "alignof_aligned is 13");
_Static_assert(ALIGNOF(array)!=14, "alignof_aligned is 14");
_Static_assert(ALIGNOF(array)!=15, "alignof_aligned is 15");
_Static_assert(ALIGNOF(array)!=16, "alignof_aligned is 16");
