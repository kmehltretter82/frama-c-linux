/* run.config
   COMMENT: frama-c/e-acsl#40, test for initialized memory after a call to fread
   on /dev/urandom.
   STDOPT:
   COMMENT: In some GCC/libc versions, GCC uses 'malloc' function attributes
   COMMENT: with deallocator names; if these deallocators have been cleaned up
   COMMENT: by Rmtmps, the resulting code will not parse. To avoid that, such
   COMMENT: attributes are erased by Frama-C's kernel. The test below checks
   COMMENT: whether code produced by E-ACSL's instrumentation remains parsable
   COMMENT: by GCC.
   COMMENT: The 'LIBS:' line below disables the filter set by E_ACSL_test.ml
   LIBS:
   LOG: @PTEST_NAME@.out.frama.c
   OPT: @GLOBAL@ @EACSL@ -cpp-extra-args="-DNO_FCLOSE" -c11 -no-frama-c-stdlib -then-last -print -ocode @PTEST_NAME@.out.frama.c
 ENABLED_IF: %{bin-available:gcc}
   EXECNOW: BIN @PTEST_NAME@.o gcc -Wno-attributes %{dep:@PTEST_NAME@.out.frama.c} -c -o @PTEST_NAME@.o >@DEV_NULL@ 2>@DEV_NULL@
*/

#include <stdio.h>

int main() {
  char buf[4];
  FILE *f = fopen("/dev/urandom", "r");
  if (f) {
    char buf[4];
    int res = fread(buf, 1, 4, f);
#ifndef NO_FCLOSE
    fclose(f);
#endif
    if (res == 4) {
      //@ assert \initialized(&buf[3]);
      buf[0] = buf[3];
    } else
      return 2;
  } else
    return 1;
  return 0;
}
