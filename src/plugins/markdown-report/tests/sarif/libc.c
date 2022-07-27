/* run.config
 CMD: @frama-c@ -eva -eva-no-results -mdr-gen sarif -mdr-sarif-deterministic
 BIN: with-libc.sarif.unfiltered
   OPT: -mdr-out ./with-libc.sarif.unfiltered
   EXECNOW: LOG with-libc.sarif sed -e "s:@PTEST_SESSION@:PTEST_SESSION:" %{dep:with-libc.sarif.unfiltered} > with-libc.sarif 2> @NULL
 BIN: without-libc.sarif.unfiltered
   OPT: -mdr-no-print-libc -mdr-out ./without-libc.sarif.unfiltered
   EXECNOW: LOG without-libc.sarif sed -e "s:@PTEST_SESSION@:PTEST_SESSION:" %{dep:without-libc.sarif.unfiltered} > without-libc.sarif 2> @NULL
*/
#include <string.h>
int main() {
  char *s = "hello world";
  int n = strlen(s);
  return n;
}
