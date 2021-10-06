/* run.config
COMMENT: dependency to FRAMA-C share directory is implicit
DEPS: jcdb2.c with_arguments.json compile_commands.json file_without_main.c
  OPT: -json-compilation-database ./ -print
  OPT: jcdb2.c -json-compilation-database with_arguments.json -print
MODULE: @PTEST_NAME@
  OPT: -json-compilation-database with_arguments.json
MODULE:
  EXECNOW: LOG list_files.res LOG list_files.err @FRAMAC_SHARE@/analysis-scripts/list_files.py %{dep:compile_commands_working.json} > list_files.res 2> list_files.err
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
