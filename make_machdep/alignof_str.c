#include "make_machdep_common.h"

_Static_assert(ALIGNOF("test string") != 1, "alignof_str is 1");
_Static_assert(ALIGNOF("test string") != 2, "alignof_str is 2");
_Static_assert(ALIGNOF("test string") != 3, "alignof_str is 3");
_Static_assert(ALIGNOF("test string") != 4, "alignof_str is 4");
_Static_assert(ALIGNOF("test string") != 5, "alignof_str is 5");
_Static_assert(ALIGNOF("test string") != 6, "alignof_str is 6");
_Static_assert(ALIGNOF("test string") != 7, "alignof_str is 7");
_Static_assert(ALIGNOF("test string") != 8, "alignof_str is 8");
