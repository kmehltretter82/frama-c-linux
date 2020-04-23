/* run.config*
   OPT: -eva @EVA_CONFIG@ -slevel 10 -eva-mlevel 0
*/
#include <stddef.h>
void *Frama_C_malloc_by_stack(size_t i);
void *Frama_C_malloc_fresh(size_t i);
void *Frama_C_malloc_imprecise(size_t i);
void main(int c) {
  int x;
  int *s;
  if(c) {
    x = 1;
    s = Frama_C_malloc_by_stack(100);
  } else {
    x = 2;
    s = 0;
  }

  int *p = Frama_C_malloc_by_stack(c);
  int *q = Frama_C_malloc_by_stack(12);
  int *r = Frama_C_malloc_fresh(100);
  *p = 1;
  *(p+2) = 3;
  *(p+24999) = 4;

  *q = 1;
  Frama_C_show_each(q+2);
  *(q+2) = 3;

  *r = 1;
  *(r+2) = 3;

  int *mw = Frama_C_malloc_imprecise(42);
  *mw = 1;
  int *mw2 = Frama_C_malloc_imprecise(42);
  *mw2 = 2;

  //  *s = 1;
}
