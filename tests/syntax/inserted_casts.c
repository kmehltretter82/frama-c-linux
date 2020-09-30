/* run.config
   MODULE: @PTEST_NAME@.cmxs
   STDOPT:
   STDOPT: +"-machdep x86_64"
*/
#include "stddef.h"
int f(int b)
{
    int r;
	if (b*b != 0)
        r=0;
	else r=-1;
    return r;
}

int g(int a)
{
  unsigned int r;
  ptrdiff_t x = &r - &r;
  r = a + 3;
  a *= r;
  return (a - r);
}
