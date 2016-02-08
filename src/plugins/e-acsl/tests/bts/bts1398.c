/* run.config
   COMMENT: variadic function call
   COMMENT: no diff
   COMMENT: no diff
   COMMENT: no diff
*/

#include "stdio.h"

int main(void) {
  int x = 0, t[2];
  int i = 1;
  t[0] = 1;
  t[1] = 2;
  printf("X=%d, t[0]=%d, t[1]=%d\n", x, t[0], t[i]);
}
