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

typedef char array[1] __attribute__((__aligned__));

_Static_assert(__alignof__(array)!=1, "gcc_alignof_aligned is 1");
_Static_assert(__alignof__(array)!=2, "gcc_alignof_aligned is 2");
_Static_assert(__alignof__(array)!=4, "gcc_alignof_aligned is 4");
_Static_assert(__alignof__(array)!=8, "gcc_alignof_aligned is 8");
_Static_assert(__alignof__(array)!=16, "gcc_alignof_aligned is 16");
_Static_assert(__alignof__(array)!=32, "gcc_alignof_aligned is 32");
