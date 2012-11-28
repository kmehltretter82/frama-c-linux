/* run.config
   COMMENT: \valid
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\"" +"-val-builtin __malloc:Frama_C_alloc_size -val-builtin __free:Frama_C_free"
   EXECNOW: LOG gen_valid.c BIN gen_valid.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/valid.c -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_valid.c > /dev/null && ./gcc_test.sh valid
   EXECNOW: LOG gen_valid2.c BIN gen_valid2.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/valid.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_valid2.c > /dev/null && ./gcc_test.sh valid2
*/

#include "stdlib.h"

extern void *malloc(size_t p);
extern void free(void* p);

int *X;

/*@ requires \valid(x); 
  @ ensures \valid(\result); */
int *f(int *x) { 
  int *y; 
  /*@ assert ! \valid(y); */
  y = x;
  /*@ assert \valid(x); */
  return y; 
}

int main(void) {
  int *a, *b, n = 0;
  /*@ assert ! \valid(a) && ! \valid(b) && ! \valid(X); */
  a = malloc(sizeof(int));
  /*@ assert \valid(a) && ! \valid(b) && ! \valid(X); */
  X = a;
  /*@ assert \valid(a) && ! \valid(b) && \valid(X); */
  b = f(&n);
  /*@ assert \valid(a) && \valid(b) && \valid(X); */
  X = b;
  /*@ assert \valid(a) && \valid(b) && \valid(X); */
  free(a);
  /*@ assert ! \valid(a) && \valid(b) && \valid(X); */
  return 0;
}
