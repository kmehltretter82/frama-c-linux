/* run.config*
   OPT: -eva @EVA_CONFIG@ -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2
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

void main()
{
  f1();
  Frama_C_dump_each();
  f1(); // This call should reuse the summary of f1
}