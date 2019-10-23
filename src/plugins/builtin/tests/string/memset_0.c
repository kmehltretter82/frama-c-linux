#include <string.h>

struct X {
  int x ;
  int y ;
} ;

typedef int named ;

void chars(char dest[10]){
  char* res = memset(dest, 0, 10);
  memset(res, 0, 10);
}

void uchars(unsigned char dest[10]){
  unsigned char* res = memset(dest, 0, 10);
  memset(res, 0, 10);
}

void nested_chars(char dest[10][10]){
  char (*res) [10] = memset(dest, 0, 100);
  memset(res, 0, 100);
}

void integer(int dest[10]){
  int * res = memset(dest, 0, 10 * sizeof(int));
  memset(res, 0, 10 * sizeof(int));
}

void floats(float dest[10]){
  float * res = memset(dest, 0, 10 * sizeof(float));
  memset(res, 0, 10 * sizeof(float));
}

void with_named(named dest[10]){
  named * res = memset(dest, 0, 10 * sizeof(named));
  memset(res, 0, 10 * sizeof(named));
}

void structure(struct X dest[10]){
  struct X * res = memset(dest, 0, 10 * sizeof(struct X));
  memset(res, 0, 10 * sizeof(struct X));
}

void pointers(int* dest[10]){
  int ** res = memset(dest, 0, 10 * sizeof(int*));
  memset(res, 0, 10 * sizeof(int*));
}

void nested(int (*dest)[10], int n){
  int (*res) [10] = memset(dest, 0, n * sizeof(int[10]));
  memset(res, 0, n * sizeof(int[10]));
}
