#include <string.h>

struct X {
  int x ;
  int y ;
} ;

typedef int named ;

int integer(int src[10], int dest[10]){
  return memcmp(dest, src, 10 * sizeof(int));
}

int with_named(named src[10], named dest[10]){
  return memcmp(dest, src, 10 * sizeof(named));
}

int structure(struct X src[10], struct X dest[10]){
  return memcmp(dest, src, 10 * sizeof(struct X));
}

int pointers(int* src[10], int* dest[10]){
  return memcmp(dest, src, 10 * sizeof(int*));
}

int nested(int (*src)[10], int (*dest)[10], int n){
  return memcmp(dest, src, n * sizeof(int[10]));
}
