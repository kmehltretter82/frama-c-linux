/* run.config
   PLUGIN: eva,from,scope,markdown-report
   MACRO: TEST_OPTION -eva -eva-no-results -mdr-gen sarif -mdr-sarif-deterministic
   LOG: with-libc.sarif
   OPT: @TEST_OPTION@ -mdr-out with-libc.sarif
   LOG: without-libc.sarif
   OPT: @TEST_OPTION@ -mdr-no-print-libc -mdr-out without-libc.sarif
*/
#include <string.h>

int main() {
  char *s = "hello world";
  int n = strlen(s);
  return n;
}
