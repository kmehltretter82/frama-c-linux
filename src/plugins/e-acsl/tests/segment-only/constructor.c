/* run.config
   COMMENT: bts #2405. Memory not initialized for code executed before main.
*/

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

__attribute__((constructor))
void f() {
  printf("f\n");
  char *buf = (char*)malloc(10*sizeof(char));
  free(buf);
}

int main() {
  printf("main\n");
  int *p = &errno;
  // TODO: see e_acsl_safe_locations.h regarding the standard streams
  /*@ assert ! \valid(p);      */ ;
  /*@ assert ! \valid(stderr); */ ;
  /*@ assert ! \valid(stdin);  */ ;
  /*@ assert ! \valid(stdout); */ ;
  return 0;
}