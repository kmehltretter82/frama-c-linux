/* run.config
    OPT: -eva @EVA_CONFIG@ -eva-no-alloc-returns-null -eva-mlevel 2 -eva-msg-key=memexec,widening,malloc,alloc-summary -eva-save-widenings -eva-reuse-widenings
*/
#include <stdlib.h>

void free_p(int **arr)
{
    for (int i = 0; i < 3; i++)
    {
        free(*(arr + i));
    }
}

int a;

void loop()
{
    a++;
    int **arr = malloc(sizeof(int *) * 3);

    Frama_C_dump_each_pre();
    for (int i = 0; i < 3; i++) // No widening reuse because it is a malloced function
    {
        *(arr + i) = malloc(sizeof(int));
    }
    Frama_C_dump_each_post();

    free_p(arr);
    free(arr);
}

int main()
{
    a = 0;
    loop();
    a = 1;
    loop();
}