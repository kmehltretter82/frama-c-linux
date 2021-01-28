/*run.config
<<<<<<< HEAD
  STDOPT: +"-no-print-libc -print -ocode ocode_@PTEST_NUMBER@_@PTEST_NAME@.c -then ocode_@PTEST_NUMBER@_@PTEST_NAME@.c"
||||||| ac7807782d
  STDOPT: #"-no-print-libc -print -ocode @PTEST_DIR@/result/ocode_@PTEST_NUMBER@_@PTEST_NAME@.c -then @PTEST_DIR@/result/ocode_@PTEST_NUMBER@_@PTEST_NAME@.c"
=======
  STDOPT: +"-no-print-libc -print -ocode @PTEST_DIR@/result/ocode_@PTEST_NUMBER@_@PTEST_NAME@.c -then @PTEST_DIR@/result/ocode_@PTEST_NUMBER@_@PTEST_NAME@.c"
>>>>>>> origin/master
*/

// tests that using -no-print-libc on a file with an enum produces output that
// is reparsable by Frama-C

#include <netinet/in.h>

int main() {
  return IPPROTO_ICMP; // force the enum to be used
}
