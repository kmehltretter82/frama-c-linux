/* run.config*
   GCC:
   STDOPT: #"-main cassign_test -eva-partition-history 1 -eva-interprocedural-partitioning-keep-history"
   STDOPT: #"-main fabs_test -eva-partition-history 1 -eva-domains equality -eva-interprocedural-partitioning-keep-history"
   */

#include "__fc_builtin.h"

int cassign(int *p)
{
  if (Frama_C_nondet(0,1))
  {
    *p = 0;
    return 1;
  }

  return 0;
}

void cassign_test(void) {
  int x, y;

  // First call
  if (cassign(&x)) {
    y = x + 1;
    Frama_C_show_each(y);
  }

  // Second call with some MemExec hit
  if (cassign(&x)) {
    y = x + 1;
    Frama_C_show_each(y);
  }
}


double fabs(double x)
{
  if (x == 0.0) {
    return 0.0;
  } else if (x > 0.0) {
    return x;
  } else {
    return -x;
  } 
}

void fabs_test(double x)
{
  if (fabs(x) > 1.0) {
    x = x < 0 ? -1.0 : 1.0;
  }
}
