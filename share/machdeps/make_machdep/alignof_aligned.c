/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
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
