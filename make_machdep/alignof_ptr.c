#include "make_machdep_common.h"

_Static_assert(ALIGNOF(void *) != 1, "alignof_ptr is 1");
_Static_assert(ALIGNOF(void *) != 2, "alignof_ptr is 2");
_Static_assert(ALIGNOF(void *) != 3, "alignof_ptr is 3");
_Static_assert(ALIGNOF(void *) != 4, "alignof_ptr is 4");
_Static_assert(ALIGNOF(void *) != 5, "alignof_ptr is 5");
_Static_assert(ALIGNOF(void *) != 6, "alignof_ptr is 6");
_Static_assert(ALIGNOF(void *) != 7, "alignof_ptr is 7");
_Static_assert(ALIGNOF(void *) != 8, "alignof_ptr is 8");
