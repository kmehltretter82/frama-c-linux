/* run.config
   COMMENT: initialized and function calls
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\""
   EXECNOW: LOG gen_ptr_init.c BIN gen_ptr_init.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/ptr_init.c -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_ptr_init.c > /dev/null && ./gcc_test.sh ptr_init
   EXECNOW: LOG gen_ptr_init2.c BIN gen_ptr_init2.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/ptr_init.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_ptr_init2.c > /dev/null && ./gcc_test.sh ptr_init2
*/

#include "stdlib.h"

extern void *malloc(size_t);

int *A, *B;

void f() {
  A = B;
}

void g(int *C, int* D) {
  C = D;
}

int main(void) {
  int *x, *y, *z, *t;
  B = (int*) malloc(sizeof(int));
  y = (int*) malloc(sizeof(int));
  t = (int*) malloc(sizeof(int));
  x = y; 
  f();
  g(z, t);
  /*@ assert \initialized(&A); */
  /*@ assert \initialized(&x); */
  /*@ assert \initialized(&z); */
  return 0;
}
