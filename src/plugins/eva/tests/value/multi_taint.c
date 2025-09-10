/* run.config*
   STDOPT: +" -eva-domains taint -eva-msg-key=d-taint -eva-auto-taint -eva-no-taint-singletons"
*/
#include "__fc_builtin.h"
#include <stdio.h>

void taint_simplify_singletons(int taint_var) {
  int x;
  //@ \eva::taint test:taint_var;

  int y = taint_var;

  /*@ assert y == 4; */

  // here x shouldn't be tainted because y can take only 1 value
  x = 4 - y;
  /*@ check !\tainted(auto:x); */
  /*@ check !\tainted(test:x); */
}

void multi_taint_test(int* taint_var) {
  int t, y;
  //@ \eva::taint test:*taint_var;

  t = *taint_var;
  /*@ check \tainted(auto:t); */
  /*@ check \tainted(test:t); */

  y = 10;
  /*@ \eva::taint test:y; */
  /*@ check !\tainted(auto:y); */

  if (y)
    y = 3;
  /*@ check !\tainted(auto:y); */
  
  if (t)
    y = 2;
  /*@ check !\tainted(auto:y); */

  Frama_C_dump_each();
}

int main(void) {
  int taint_var;
  scanf("%d", &taint_var);
  /*@ check \tainted(auto:taint_var); */

  taint_simplify_singletons(taint_var);
  /*@ check !\tainted(test:taint_var); */

  multi_taint_test(&taint_var);
  /*@ check !\tainted(test:taint_var); */

  return 0;
}
