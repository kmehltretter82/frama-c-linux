/* run.config
  DONTRUN:
  COMMENT:
  COMMENT:
  COMMENT:
*/
#include <stdlib.h>

void *alloc()
{
  void *buf = malloc(sizeof(int));
  return buf;
}

void foo()
{
  int *p = (int *)alloc();
  free(p);
}

void bar()
{
  int *q = (int *)alloc();
  int a = 0; // Modified
  free(q);
}

void test(void (*f)())
{
  f();
}

void main()
{
  void (*f)() = foo;
  void (*g)() = bar;

  test(f);
  test(g);
}
