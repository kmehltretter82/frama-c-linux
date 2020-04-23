/* run.config*
   STDOPT: +"-eva-builtin malloc:Frama_C_malloc_imprecise,realloc:Frama_C_realloc_imprecise"
*/

#include <stdlib.h>

volatile int v;

void main() {
  int *p = malloc(sizeof(int));
  *p = 17;
  int *pp = p;
  int *q = realloc(p, 2 * sizeof(int));
  if (v) {
    int *r = realloc(q, sizeof(int));
    free(r);
  }
}
