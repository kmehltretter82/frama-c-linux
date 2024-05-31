/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"@PTEST_FILE@ -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-msg-key=memexec @EVA_OPTIONS@"
*/
#include <stdio.h>

static void foo()
{
  static char *help_msg[] = {(char *)"Msg"}; // Not imported because "init_info" is not checked for static variables
  char **p = help_msg;
  printf("%s\n", *p);
}

int main()
{
  foo();
  return 0;
}