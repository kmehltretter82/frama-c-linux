/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"%{dep:@PTEST_NAME@.c} -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc @EVA_OPTIONS@"
*/
#include <stdlib.h>

void foo()
{
    int **p = (int **)malloc(sizeof(int *) * 3);
    //@ loop unroll 3;
    for (int i = 0; i < 3; i++)
    {
        *(p + i) = (int *)malloc(sizeof(int)); // Verify that the order of allocation is the same with incremental analysis
        **(p + i) = 0;
    }
    //@ loop unroll 3;
    for (int i = 0; i < 3; i++)
    {
        free(*(p + i));
    }

    free(p);
}

int main()
{
    foo();
    return 0;
}