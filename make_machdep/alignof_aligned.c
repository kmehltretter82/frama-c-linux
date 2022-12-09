#include "make_machdep_common.h"

char array[1] __attribute__((aligned));

unsigned char alignof_aligned = ALIGNOF(array);
