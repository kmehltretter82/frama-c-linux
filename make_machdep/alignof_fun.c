#include "make_machdep_common.h"

_Static_assert(ALIGNOF(void ()) != 1, "alignof_fun is 1");
_Static_assert(ALIGNOF(void ()) != 2, "alignof_fun is 2");
_Static_assert(ALIGNOF(void ()) != 3, "alignof_fun is 3");
_Static_assert(ALIGNOF(void ()) != 4, "alignof_fun is 4");
_Static_assert(ALIGNOF(void ()) != 5, "alignof_fun is 5");
_Static_assert(ALIGNOF(void ()) != 6, "alignof_fun is 6");
_Static_assert(ALIGNOF(void ()) != 7, "alignof_fun is 7");
_Static_assert(ALIGNOF(void ()) != 8, "alignof_fun is 8");
