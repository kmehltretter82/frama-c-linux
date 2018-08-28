/* run.config
   COMMENT: ranges in a few builtins
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

  long t[3] = {7l, 8l, 9l};
  /*@ assert \valid(&t[0..2]); */ ;
  /*@ assert !\valid(&t[3..5]); */ ;

  double t2[4];
  t2[0] = 0.5;
  t2[1] = 1.5;
  /*@ assert \initialized(&t2[0..1]); */ ;
  /*@ assert !\initialized(&t2[2..3]); */ ;

  /*@ assert !\initialized(b + (0 .. 10));*/
  free(b);

  int n = 2;
  float t3[7][2][4];
  /*@ assert !\initialized(&t3[(n-1)..(n+2)][1][0..1]); */ ;
}