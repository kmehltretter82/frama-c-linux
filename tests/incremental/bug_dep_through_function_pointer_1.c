/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  EXECNOW: BIN @PTEST_NAME@.1.sav LOG @PTEST_NAME@_sav.1.res LOG @PTEST_NAME@_sav.1.err @frama-c@ -save @PTEST_NAME@.1.sav @PTEST_FILE@ -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@ > @PTEST_NAME@_sav.1.res 2> @PTEST_NAME@_sav.1.err
  STDOPT: +"%{dep:bug_dep_through_function_pointer_2.c} -eva -eva-load %{dep:@PTEST_NAME@.1.sav} -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@"
*/
#include <stdlib.h>

void *alloc()
{
  void *buf = malloc(sizeof(int));
  return buf;
}

void foo()
{
  int *p = (int *)alloc();
  free(p);
}

void bar()
{
  int *q = (int *)alloc();
  free(q);
}

void test(void (*f)())
{
  f();
}

void main()
{
  void (*f)() = foo;
  void (*g)() = bar;

  test(f);
  test(g);
}
