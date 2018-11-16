/* run.config
   LOG: print_libc.pretty.c
   OPT: @PTEST_DIR@/empty.c -no-autoload-plugins -load-module variadic -no-print-libc -print -ocode @PTEST_DIR@/result/@PTEST_NAME@.pretty.c -then @PTEST_DIR@/result/@PTEST_NAME@.pretty.c
 */

#include <stdio.h>

int main() {
  printf("");
}
