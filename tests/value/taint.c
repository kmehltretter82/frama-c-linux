/* run.config*
   STDOPT: +" -eva-domains taint -eva-msg-key=d-taint,-d-cvalue -eva-auto-loop-unroll 10"
*/

#include <__fc_builtin.h>

volatile int undet;
int global;

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
  int y = 4;
  int buf[5] = { 0 };
  while (t > 0) {
    x = x + t;
    t--;
  }
  buf[u] = 0;
  buf[x] = buf[0] + 1;
  buf[y] = buf[0];
  /* 'y' must not be tainted here. */
  if (y > 0) {
    buf[1] = 2; // Hence neither 'buf[1]' must not.
  }
  Frama_C_dump_each();
}

void taint_3(int t) {
  int x, y, z, u;
  if (t > 0) {
    x = 1;
  }
  global = x + 1;
  y = z = u = 0;
  while (z < 3) {
    Frama_C_domain_show_each(z, y);
    if (y % 2 == 0) {
      y += 2;
      Frama_C_domain_show_each(z, y);
    }
    //@ taint z;
    z++;
  }
  if (!u)
    u = 1;
  else
    u = 2;
  Frama_C_dump_each();
}

void taint_4() {
  int z = 1;
  if (global) {
    /* Although 'z' is not tainted, all left-values in 'taint_1' must be tainted
       as 'taint_1' is called depending on the value of 'global', which is
       tainted. */
    taint_1(z);
    Frama_C_domain_show_each(z); // 'z' must remain untainted here.
  }
}

/*@ assigns *t \from u; */
void taint_5(int* t, int u);

void taint_6() {
  int i, u = 0;
  /* Since 'i' becomes taint at some point, it will make 'u' tainted via a
     control-dependency. At the end, both are tainted because of data- and
     control- dependencies. */
  for (i = 0; i < 8 || u <= 9; i++) {
    //@ split i;
    if (i == 5) {
      //@ taint i;
      i++;
    }
    u++;
  }
  Frama_C_dump_each();
}

void taint_7(int t) {
  int x, y;
  if (t > 0) {
    x = 1;
    goto L;
  }
  else {
    /* Since this assign is always executed,
       'y' should not be tainted. */
    L: y = 0;
  }
  Frama_C_dump_each();
}

int main(void) {
  int w, z;
  //@ taint w;
  w = 0;
  taint_1(w);
  Frama_C_domain_show_each(w);
  z = 0;
  w = 2;
  //@ taint w, z;
  taint_2(w, z);
  Frama_C_domain_show_each(w, z);
  z = 1;
  //@ taint w;
  taint_3(w);
  Frama_C_domain_show_each(w, global);
  taint_4();
  //@ taint w;
  taint_5(&z, w);
  Frama_C_domain_show_each(z, w);
  taint_6();
  w = 1;
  //@ taint undet;
  taint_7(undet);
  return 0;
}
