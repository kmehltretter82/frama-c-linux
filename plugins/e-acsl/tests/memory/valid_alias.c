/* run.config
   COMMENT: \valid in presence of aliasing
*/

#include "stdlib.h"

int main(void) {
  int *a, *b, n = 0;
  /*@ assert ! (\initialized(&a) && \valid(a)) && ! (\initialized(&b) && \valid(b)); */
  a = malloc(sizeof(int));
  *a = n;
  b = a;
  /*@ assert \valid(a) && \valid(b); */
  /*@ assert *b == n; */
  free(b);
  /*@ assert ! (\initialized(&a) && \valid(a)) && ! (\initialized(&b) && \valid(b)); */
  return 0;
}
