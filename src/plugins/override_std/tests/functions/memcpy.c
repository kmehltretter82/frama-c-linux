#include <string.h>

int main(void){
  int src[10] = { 0 } ;
  int dest[10] ;

  int *p = memcpy(dest, src, sizeof(src));
}

void nested(int (*dest) [10], int (*src) [10], size_t n){
  memcpy(dest, src, n) ;
}