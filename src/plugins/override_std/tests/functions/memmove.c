#include <string.h>

int main(void){
  int src[10] = { 0 } ;
  int dest[10] ;

  int *p = memmove(dest, src, sizeof(src));
}