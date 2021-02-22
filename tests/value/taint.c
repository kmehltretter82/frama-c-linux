/* run.config*
   STDOPT: +" -eva-domains taint -eva-msg-key=d-taint,-d-cvalue"
*/

#include <__fc_builtin.h>

volatile int undet;

void taint_1(int t) {
  int x, y;
  int buf[5] = { 0 };
  x = t + 1;
  if (undet)
    y = 2;
  else
    y = x;
  buf[y] = buf[0] + 1;
  t = 1;
  Frama_C_dump_each();
}

int main(void) {
   int w;
   w = 0;
   //@ taint w;
   w = w;
   taint_1(w);
   Frama_C_domain_show_each(w);
   return 0;
}
