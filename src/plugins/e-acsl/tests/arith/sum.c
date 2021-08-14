/* run.config
   COMMENT: sum operations
*/

#include <limits.h>

int main(void) {
  unsigned long x = UINT_MAX;
  int y = 10;

  /*@ assert \sum(2, 10, \lambda integer k; 2 * k) == 108; */;
  /*@ assert \sum(2, 35, \lambda integer k; ULLONG_MAX) != 0; */;
  /*@ assert \sum(10, 2, \lambda integer k; k) == 0; */;
  /*@ assert \sum(x * x, 2, \lambda integer k; k) == 0; */;
  /*@ assert \sum(ULLONG_MAX - 5, ULLONG_MAX, \lambda integer k; 1) == 6; */;

  return 0;
}
