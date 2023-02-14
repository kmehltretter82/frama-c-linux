#include <stddef.h>
#include "make_machdep_common.h"

_Static_assert(!COMPATIBLE(unsigned int, size_t), "size_t is unsigned int");
_Static_assert(!COMPATIBLE(unsigned long, size_t), "size_t is unsigned long");
