#include "make_machdep_common.h"
#include <stddef.h>
#define TEST_TYPE wchar_t

TEST_TYPE_MAYBE_(unsigned short, unsigned_short);
TEST_TYPE_MAYBE(short);
TEST_TYPE_MAYBE_(unsigned int, unsigned_int);
TEST_TYPE_MAYBE(int);
TEST_TYPE_MAYBE(long);
