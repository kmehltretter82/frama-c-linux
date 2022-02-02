/* run.config
<<<<<<< HEAD
COMMENT: dependency to FRAMA-C share directory is implicit
DEPS: jcdb2.c with_arguments.json compile_commands.json file_without_main.c
  OPT: -json-compilation-database ./ -print
  OPT: jcdb2.c -json-compilation-database with_arguments.json -print
MODULE: @PTEST_NAME@
  OPT: -json-compilation-database with_arguments.json
MODULE:
  EXECNOW: LOG list_files.res LOG list_files.err @FRAMAC_SHARE@/analysis-scripts/list_files.py %{dep:compile_commands_working.json} > list_files.res 2> list_files.err
||||||| 754e522ceb
EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -json-compilation-database @PTEST_DIR@ -print
OPT: @PTEST_DIR@/jcdb2.c -json-compilation-database @PTEST_DIR@/with_arguments.json -print
OPT: -json-compilation-database @PTEST_DIR@/with_arguments.json -no-autoload-plugins -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs
EXECNOW: LOG list_files.res LOG list_files.err share/analysis-scripts/list_files.py @PTEST_DIR@/compile_commands_working.json > @PTEST_DIR@/result/list_files.res 2> @PTEST_DIR@/result/list_files.err
=======
 DEPS: compile_commands.json
 COMMENT: parsing option are defined in the default json file "compile_commands.json"
   OPT: -json-compilation-database @PTEST_DIR@ -print
 DEPS:
   OPT: %{dep:@PTEST_DIR@/jcdb2.c} -json-compilation-database %{dep:@PTEST_DIR@/with_arguments.json} -print
 MODULE: @PTEST_NAME@
   OPT: -json-compilation-database %{dep:@PTEST_DIR@/with_arguments.json}
 MODULE:
   EXECNOW: LOG list_files.res LOG list_files.err %{bin:frama-c-script} list-files %{dep:@PTEST_DIR@/compile_commands_working.json} > @PTEST_RESULT@/list_files.res 2> @PTEST_RESULT@/list_files.err
>>>>>>> origin/master
*/
<<<<<<< HEAD


||||||| 754e522ceb
=======

>>>>>>> origin/master
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
