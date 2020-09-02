/* run.config
CMXS: @PTEST_NAME@
OPT: -json-compilation-database @PTEST_DIR@ -print
OPT: @PTEST_DIR@/jcdb2.c -json-compilation-database @PTEST_DIR@/with_arguments.json -print
OPT: -json-compilation-database @PTEST_DIR@/with_arguments.json -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
EXECNOW: LOG list_files.res LOG list_files.err share/analysis-scripts/list_files.py @PTEST_DIR@/compile_commands_working.json > list_files.res 2> list_files.err
*/
#include <stdio.h>

#ifdef TOUNDEF
#error TOUNDEF must be undefined by the compilation database
#endif

int main () {
  char *s = DOUBLE_SINGLE("a ");
  #ifndef __FRAMAC__
  printf("%s\n", s); // for GCC debugging
  #endif
  return MACRO_FOR_INCR(TEST); }
