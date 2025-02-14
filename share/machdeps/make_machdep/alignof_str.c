/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

#include "make_machdep_common.h"

_Static_assert(ALIGNOF("test string") != 1, "alignof_str is 1");
_Static_assert(ALIGNOF("test string") != 2, "alignof_str is 2");
_Static_assert(ALIGNOF("test string") != 4, "alignof_str is 4");
_Static_assert(ALIGNOF("test string") != 8, "alignof_str is 8");
_Static_assert(ALIGNOF("test string") != 16, "alignof_str is 16");
_Static_assert(ALIGNOF("test string") != 32, "alignof_str is 32");
