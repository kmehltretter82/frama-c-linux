#include "make_machdep_common.h"
#include <stddef.h>
#define TEST_TYPE ptrdiff_t

TEST_TYPE_IS(int);
TEST_TYPE_IS(long);
TEST_TYPE_IS(long long);
