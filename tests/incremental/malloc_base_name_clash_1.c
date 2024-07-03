/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"%{dep:malloc_base_name_clash_2.c} -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@"
*/
#include <stdlib.h>

void alloc(int size)
{
    int *p = (int *)malloc(sizeof(int) * size);
    *p = 0;
}

void foo()
{
    alloc(1);
}

void bar()
{
    alloc(2);
}

int main()
{
    foo();
    bar();
    return 0;
}