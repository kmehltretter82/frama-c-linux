#include "make_machdep_common.h"

__attribute__((section(".data")))
unsigned char char_is_unsigned = (char)-1 >= 0 ? 0x15 : 0xf4;
