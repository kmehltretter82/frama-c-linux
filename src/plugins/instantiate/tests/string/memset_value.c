#include <string.h>

struct X {
  int x ;
  int y ;
} ;

typedef int named ;

void chars(char dest[10], char value){
  char* res = memset(dest, value, 10);
  memset(res, value, 10);
}

void uchars(char dest[10], unsigned char value){
  unsigned char* res = memset(dest, value, 10);
  memset(res, value, 10);
}

void nested_chars(char dest[10][10], char value){
  char (*res) [10] = memset(dest, value, 100);
  memset(res, value, 100);
}

void integer(int dest[10], int value){
  int * res = memset(dest, value, 10 * sizeof(int));
  memset(res, value, 10 * sizeof(int));
}

void with_named(named dest[10], int value){
  named * res = memset(dest, value, 10 * sizeof(named));
  memset(res, value, 10 * sizeof(named));
}

void structure(struct X dest[10], int value){
  struct X * res = memset(dest, value, 10 * sizeof(struct X));
  memset(res, value, 10 * sizeof(struct X));
}

void pointers(int* dest[10], int value){
  int ** res = memset(dest, value, 10 * sizeof(int*));
  memset(res, value, 10 * sizeof(int*));
}

void nested(int (*dest)[10], int n, int value){
  int (*res) [10] = memset(dest, value, n * sizeof(int[10]));
  memset(res, value, n * sizeof(int[10]));
}

void with_void(void* dest, int value){
  void* res = memset(dest, value, 10);
  memset(res, value, 10);
}
