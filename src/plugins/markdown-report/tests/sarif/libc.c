/* run.config
   LOG: @PTEST_DIR@/oracle/with-libc.sarif.clean
   EXECNOW: @frama-c@ @PTEST_FILE@ -no-autoload-plugins -load-module eva,from,scope,markdown_report -eva -mdr-gen sarif -mdr-out @PTEST_DIR@/oracle/with-libc.sarif && sed -e "s:$FRAMAC_SHARE:REPLACED_FOR_PTESTS_FRAMAC_SHARE:g" -e "s:$FRAMAC_LIB:REPLACED_FOR_PTESTS_FRAMAC_LIB:g" -e "s:$FRAMAC_PLUGIN:REPLACED_FOR_PTESTS_FRAMAC_PLUGIN:g" -e "s:$PWD:REPLACED_FOR_PTESTS_PWD:g" @PTEST_DIR@/oracle/with-libc.sarif > @PTEST_DIR@/oracle/with-libc.sarif.clean && rm -f @PTEST_DIR@/oracle/with-libc.sarif
   EXECNOW: @frama-c@ @PTEST_FILE@ -no-autoload-plugins -load-module eva,from,scope,markdown_report -eva -mdr-gen sarif -mdr-out @PTEST_DIR@/oracle/without-libc.sarif -mdr-no-print-libc && sed -e "s:$FRAMAC_SHARE:REPLACED_FOR_PTESTS_FRAMAC_SHARE:g" -e "s:$FRAMAC_LIB:REPLACED_FOR_PTESTS_FRAMAC_LIB:g" -e "s:$FRAMAC_PLUGIN:REPLACED_FOR_PTESTS_FRAMAC_PLUGIN:g" -e "s:$PWD:REPLACED_FOR_PTESTS_PWD:g" @PTEST_DIR@/oracle/without-libc.sarif > @PTEST_DIR@/oracle/without-libc.sarif.clean && rm -f @PTEST_DIR@/oracle/without-libc.sarif
*/

#include <string.h>

int main() {
  char *s = "hello world";
  int n = strlen(s);
  return n;
}
