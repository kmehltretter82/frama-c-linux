/* run.config
   COMMENT: The \valid built-in predicate.
*/

/* run.config_dev
   COMMENT: Print the data and filter the addresses of the output so that the test is deterministic.
   MACRO: ROOT_EACSL_EXEC_FILTER sed -e s/0x[0-9a-f]*$/0x000000/g
*/

#include "stdlib.h"

int *X, Z;

/*@ requires \valid(x);
  @ ensures \valid(\result); */
int *f(int *x) {
  int *y;
  /*@ assert ! \valid(y); */
  y = x;
  /*@ assert \valid(x); */
  return y;
}

void g(void) {
  int m, *u, **p;
  p = &u;
  u = &m;
  m = 123;
  //@ assert \valid(*p);
}

//@ predicate P(int *i) = \valid(i);

int main(void) {
  int *a, *b, **c, ***d, n = 0;
  /*@ assert ! \valid(a) && ! \valid(b) && ! \valid(X); */
  a = malloc(sizeof(int));
  /*@ assert \valid(a) && ! \valid(b) && ! \valid(X); */
  X = a;
  /*@ assert \valid(a) && ! \valid(b) && \valid(X); */
  b = f(&n);
  /*@ assert \valid(a) && \valid(b) && \valid(X); */
  X = b;
  /*@ assert \valid(a) && \valid(b) && \valid(X); */
  c = &a;
  d = &c;
  /*@ assert \valid(*c); */
  /*@ assert \valid(**d); */
  free(a);
  /*@ assert ! \valid(a) && \valid(b) && \valid(X); */
  /*@ assert \valid(&Z); */
  g();
  int i = 3;
  //@ check P(&i);
  return 0;
}
