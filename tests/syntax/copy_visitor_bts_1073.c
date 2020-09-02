/* run.config
CMXS: @PTEST_NAME@
CMXS: @PTEST_NAME@_bis
OPT: -load-module %{dep:@PTEST_NAME@.cmxs}
OPT: -load-module @PTEST_DIR@/@PTEST_NAME@_bis -test -then-on filtered -print
*/

#include "stdio.h"

int f(int x);

int f(int x) { return x; }

int g(int y) { return f(2*y); }

int main (int argc, char * argv[]) {
  int i;

  printf ("Hello !\n");

  for (i = 0; i < argc; i++)
    printf ("arg %d : %s\n", i, argv[i]);

  printf ("Found %d arguments\n", i - 1);

  return 0;
}
