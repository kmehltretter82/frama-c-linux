/* run.config
  COMMENT: Temporal analysis with respect dynamic memory allocation.
  COMMENT: malloc-free-malloc errors
*/

#include <stdlib.h>

int main(void) {
  int *p, *q;

  /*@assert ! (\initialized(&p) && \valid(p)); */
  /*@assert ! (\initialized(&q) && \valid(q)); */

  p = (int *)malloc(sizeof(int));
  q = p;

  /*@assert \valid(p); */
  /*@assert \valid(q); */

  free(q);

  /*@assert ! (\initialized(&p) && \valid(p)); */
  /*@assert ! (\initialized(&q) && \valid(q)); */

  p = (int *)malloc(sizeof(int));
  /* q is temporally invalid: points to the block allocated by the first malloc
     call which has been deallocated, while p is valid */
  /*@assert \valid(p); */
  /*@assert ! (\initialized(&q) && \valid(q));*/
  *q = 1;
  *p = 2;

  /* ... and for calloc .. */
  q = (char *)calloc(4096, 1);
  /*@assert \valid(q); */

  /* ... and and realloc  */
  q = (char *)realloc(q, 8192);
  /*@assert \valid(q); */
  return 0;
}
