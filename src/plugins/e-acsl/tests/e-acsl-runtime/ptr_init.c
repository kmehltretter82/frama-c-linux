/* run.config
   COMMENT: initialized and function calls
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\""
   COMMENT: no diff
   EXECNOW: LOG gen_ptr_init2.c BIN gen_ptr_init2.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/ptr_init.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_ptr_init2.c > /dev/null && ./gcc_runtime.sh ptr_init2
*/

#include "stdlib.h"

extern void *malloc(size_t);

int *A, *B;

void f() {
  A = B;
}

void g(int *C, int* D) {
  /*@ assert \initialized(&C); */
}

int main(void) {
  int *x, *y;
  B = (int*) malloc(sizeof(int));
  y = (int*) malloc(sizeof(int));
  x = y; 
  f();
  /*@ assert \initialized(&A); */
  /*@ assert \initialized(&x); */
  g(x, y);
  return 0;
}
