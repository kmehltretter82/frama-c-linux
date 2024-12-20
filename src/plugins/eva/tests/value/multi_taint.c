/* run.config*
   STDOPT: +" -eva-domains taint -eva-auto-taint -eva-no-taint-singletons"
*/
#include <stdio.h>

void taint_simplify_singletons(int taint_var) {
  int x;
  int y = taint_var;

  /*@ assert y == 4; */

  // here x shouldn't be tainted because y can take only 1 value
  x = 4 - y;
  /*@ check !\tainted(auto:x); */
}

void multi_taint_test(int taint_var) {
  int t, y;

  t = taint_var;
  /*@ check \tainted(auto:t); */

  y = 10;
  /*@ \eva::taint test:y; */
  /*@ check !\tainted(auto:y); */
}

int main(void) {
  int taint_var;
  scanf("%d", &taint_var);
  /*@ check \tainted(auto:taint_var); */

  taint_simplify_singletons(taint_var);

  multi_taint_test(taint_var);

  return 0;
}
