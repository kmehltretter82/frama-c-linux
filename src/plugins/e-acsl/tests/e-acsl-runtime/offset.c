/* run.config
   COMMENT: Behaviours of the \offset E-ACSL predicate
*/

#include <stdlib.h>

int main() {
  /* Stack offsets */
  char c;
  /*@assert \offset(&c) == 0; */

  short slist[3];
  short *ps = slist;
  /*@assert \offset(ps) == 0; */
  /*@assert \offset(ps + 1) == 2; */
  /*@assert \offset(ps + 2) == 4; */

  int ilist [3];
  int *pi = ilist;
  /*@assert \offset(pi) == 0; */
  /*@assert \offset(pi + 1) == 4; */
  /*@assert \offset(pi + 2) == 8; */

  /* Heap offsets */
  long *p = (long*)malloc(sizeof(long)*12);
  /*@assert \offset(p) == 0; */
  /*@assert \offset(p+1) == 8; */
  /*@assert \offset(p+2) == 16; */
  return 0;
}
