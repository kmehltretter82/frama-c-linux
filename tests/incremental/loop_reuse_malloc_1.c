/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=memexec,widening,malloc,alloc-summary @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"%{dep:loop_reuse_malloc_2.c} -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=memexec,widening,malloc,alloc-summary @EVA_OPTIONS@"
*/
#include <stdlib.h>

int a;

void *alloc()
{
    int *p = malloc(sizeof(int));
    *p = 0;
    return p;
}

void init_p(int **arr)
{
    a++;
    for (int i = 0; i < 3; i++)
    {
        *(arr + i) = alloc();
    }
}

void free_p(int **arr)
{
    a++;
    for (int i = 0; i < 3; i++)
    {
        free(*(arr + i));
    }
}

void loop()
{
    a++;
    int **arr = malloc(sizeof(int *) * 3);

    init_p(arr);
    free_p(arr);

    free(arr);
}

int main()
{
    a = 0;
    loop();
}