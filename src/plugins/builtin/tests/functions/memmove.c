#include <string.h>

int main(void){
  int src[10] = { 0 } ;
  int dest[10] ;

  int *p = memmove(dest, src, sizeof(src));
}

int* nested(int (*dest) [10], int (*src) [10], size_t n){
  memmove(dest, src, n) ;
}