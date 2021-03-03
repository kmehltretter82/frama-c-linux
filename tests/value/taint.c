/* run.config*
   STDOPT: +" -eva-domains taint -eva-msg-key=d-taint,-d-cvalue -eva-auto-loop-unroll 10"
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

void taint_2(int t, int u) {
  int x = 0;
  int buf[5] = { 0 };
  while (t > 0) {
    x = x + t;
    t--;
  }
  buf[u] = 0;
  buf[x] = buf[0] + 1;
  Frama_C_dump_each();
}

int main(void) {
  int w, z;
  w = z = 0;
  //@ taint w;
  taint_1(w);
  Frama_C_domain_show_each(w);
  w = 2;
  //@ taint w, z;
  taint_2(w, z);
  Frama_C_domain_show_each(w, z);
  return 0;
}
