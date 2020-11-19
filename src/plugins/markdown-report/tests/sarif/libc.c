/* run.config
   CMD: @frama-c@ @PTEST_FILE@ -no-autoload-plugins -load-module eva,from,scope,markdown_report -eva -eva-no-results -mdr-gen sarif -mdr-sarif-deterministic
   LOG: with-libc.sarif
   OPT: -mdr-out @PTEST_DIR@/result/with-libc.sarif
   LOG: without-libc.sarif
   OPT: -mdr-no-print-libc -mdr-out @PTEST_DIR@/result/without-libc.sarif
*/

#include <string.h>

int main() {
  char *s = "hello world";
  int n = strlen(s);
  return n;
}
