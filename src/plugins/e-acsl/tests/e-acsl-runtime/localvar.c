/* run.config
   COMMENT: allocation and de-allocation of local variables
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\"" +"-val-builtin _malloc:Frama_C_alloc_size -val-builtin _free:Frama_C_free -val-split-return-function _initialized:0 -slevel 2"
   EXECNOW: LOG gen_localvar.c BIN gen_localvar.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/localvar.c -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_localvar.c > /dev/null && ./gcc_test.sh localvar
   EXECNOW: LOG gen_localvar2.c BIN gen_localvar2.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/localvar.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_localvar2.c > /dev/null && ./gcc_test.sh localvar2
*/

#include <stdlib.h>

extern void *malloc(size_t size);

struct list {
  int element;
  struct list * next;
};

struct list * add(struct list * l, int i) {
  struct list * new;
  new = malloc(sizeof(struct list));
  /*@ assert \valid(new); */
  new->element = i;
  new->next = l;
  return new;
}

int main() {
  struct list * l = NULL;
  l = add(l, 4);
  l = add(l, 7);
  return 0;
}
