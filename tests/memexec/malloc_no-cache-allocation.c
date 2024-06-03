/* run.config*
   OPT: -eva @EVA_CONFIG@ -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2 -eva-no-cache-allocation
*/
#include <stdlib.h>

void *alloc()
{
  int *p = malloc(sizeof(int));
  return p;
}

void f1()
{
  void *p = alloc();
  free(p);
}

void f2()
{
  int a = 0;
}

void main()
{
  f1();
  f1(); // No summary reuse, cache allocation is disabled
  f2();
  f2(); // This call should reuse the summary of f2
}