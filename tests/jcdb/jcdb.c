/* run.config
DEPS: jcdb2.c with_arguments.json compile_commands.json
CMXS: @PTEST_NAME@
OPT: -json-compilation-database ./ -print
OPT: jcdb2.c -json-compilation-database with_arguments.json -print
OPT: -json-compilation-database with_arguments.json -load-module %{dep:@PTEST_NAME@.cmxs}
EXECNOW: LOG list_files.res LOG list_files.err %{read:../syntax/framac_share_path}/analysis-scripts/list_files.py %{dep:compile_commands_working.json} > list_files.res 2> list_files.err
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
