/* run.config
   COMMENT: function contract involving \valid
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\"" +"-val-builtin _malloc:Frama_C_alloc_size -val-builtin _free:Frama_C_free -val-split-return-function _initialized:0 -slevel 2"
   EXECNOW: LOG gen_valid_in_contract.c BIN gen_valid_in_contract.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/valid_in_contract.c -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_valid_in_contract.c > /dev/null && ./gcc_test.sh valid_in_contract
   EXECNOW: LOG gen_valid_in_contract2.c BIN gen_valid_in_contract2.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/valid_in_contract.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_valid_in_contract2.c > /dev/null && ./gcc_test.sh valid_in_contract2
*/

#include <stdlib.h>

struct list {
  int element;
  struct list * next;
};

/*@
  @ behavior B1:
  @  assumes l == \null;
  @  ensures \result == l;
  @ behavior B2:
  @  assumes \valid(l);
  @  assumes l->next == \null;
  @  ensures \result == l;
*/
struct list * f(struct list * l) {
  /* length = 0 */
  if(l == NULL) return l;
  /* length = 1 : already sorted */
  if(l->next == NULL) return l;

  return NULL;
}

int main() {
  f(NULL);
  return 0;
}
