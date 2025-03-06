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

_Static_assert(__alignof__(double) != 1, "gcc_alignof_double is 1");
_Static_assert(__alignof__(double) != 2, "gcc_alignof_double is 2");
_Static_assert(__alignof__(double) != 4, "gcc_alignof_double is 4");
_Static_assert(__alignof__(double) != 8, "gcc_alignof_double is 8");
_Static_assert(__alignof__(double) != 16, "gcc_alignof_double is 16");
_Static_assert(__alignof__(double) != 32, "gcc_alignof_double is 32");
