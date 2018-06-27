/* run.config
   COMMENT: ranges in builtins
*/

#include "stdlib.h"

extern void *malloc(size_t p);
extern void free(void* p);

int main(void) {
  int *a;
  a  = malloc(10*sizeof(int));
  /*@ assert \valid(a + (0 .. 4)); */ ;
  int j = 2;
  /*@ assert \valid(a + (4 .. 8+j)); */ ;
  /*@ assert !\valid(a + (10 .. 11)); */ ;
  free(a);

  char *b;
  b  = malloc(10*sizeof(char));
 /*@ assert \valid(b + (0 .. 10)); */ ;
 /*@ assert !\valid(b + (11 .. 15)); */ ;
  free(b);

  long t[3] = {7l, 8l, 9l};
  /*@ assert \valid(&t[0..2]); */ ;
  /*@ assert !\valid(&t[3..5]); */ ;
}