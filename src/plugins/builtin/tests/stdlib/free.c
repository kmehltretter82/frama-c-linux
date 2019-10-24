#include <stdlib.h>

void foo(int * x){
  free(x);
}
void bar(float * x){
  free(x);
}
void baz(int (*x) [10]){
  free(x);
}