/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"%{dep:@PTEST_NAME@.c} -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@"
*/
#include <stdlib.h>

void alloc()
{
    int *p = (int *)malloc(sizeof(int));
    free(p);
}

void foo()
{
    alloc();
}

void bar()
{
    alloc();
}

int main()
{
    foo(); // Allocate new base here
    foo(); // Reuse the base
    bar(); // Allocate new base here, We don't reuse base allocated by foo because they are in different call stack
    bar(); // Reuse the base
    return 0;
}