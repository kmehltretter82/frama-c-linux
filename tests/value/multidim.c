/* run.config*
   STDOPT: #"-main main -eva-msg-key d-multidim -eva-domains multidim -eva-plevel 1"
   STDOPT: #"-main main2 -eva-msg-key d-multidim -eva-domains multidim -eva-plevel 1"
   STDOPT: #"-main main3 -eva-msg-key d-multidim -eva-domains multidim -eva-plevel 1"
*/
#include "__fc_builtin.h"
#define N 4
#define M 4

typedef struct {
  float f;
  int i;
} t;

typedef struct {
  t t1[N];
  t t2[N];
} s;

/*@ axiomatic float_memory {
    predicate \are_finite(set<float> sf);
  }
*/

s z[M];

/*@ assigns z[..] \from \nothing;
    ensures \are_finite(z[..].t1[..].f) && \are_finite(z[..].t2[..].f);
  */
void f();

volatile int nondet;

void main(s x) {
  s y1 = {{{{3.0}}}};
  s y2;

  if (nondet)
    y2.t1[0].f = 4.0;

  Frama_C_domain_show_each(x, y1, y2, z);

  /* The multidim domain wont infer anything except the structure from the
     assign: it considers x can contain anything including pointers, and thus no
     reduction is done by are_finite */
  //@ admit \are_finite(x.t1[..].f) && \are_finite(x.t2[..].f);
  Frama_C_domain_show_each(x);

  f();
  Frama_C_domain_show_each(z);  
  /* The multidim domain doesn't implement forward logic yet */
  //@ check \are_finite(z[..].t1[..].f) && \are_finite(z[..].t2[..].f);
}

void main2(void) {
  int t[10] = {0};
  for (int i = 0 ; i < 10 ; i++) {
    t[i] = 1;
  }
  Frama_C_domain_show_each(t);
  //@ check t[0..9] == 1;
}

void main3(void) {
  for (int i = 0 ; i < M ; i ++) {
    for (int j = 0 ; j < N ; j ++) {
      z[i].t1[j].f = 2.0;
      z[i].t1[j].i = 2;
    }
  }
  
  Frama_C_domain_show_each(z);

  int a = Frama_C_interval(0,M-1);
  int b = Frama_C_interval(0,N-1);
  t r = z[a].t1[b];
  Frama_C_domain_show_each(r);
}
