#include <string.h>

int main(void){
  int src[10] = { 0 } ;
  int dest[10] ;

  int *p = memcpy(dest, src, sizeof(src));
}