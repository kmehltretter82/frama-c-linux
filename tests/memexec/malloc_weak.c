/* run.config*
   OPT: -eva @EVA_CONFIG@ -out-external -input -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2
*/

#include <stdlib.h>

void p_init(int **p)
{
    //@ loop unroll 3;
    for (int i = 0; i < 3; i++)
    {
        *(p + i) = (int *)malloc(sizeof(int));
        **(p + i) = 42;
    }
}

void p_free(int **p)
{
    //@ loop unroll 3;
    for (int i = 0; i < 3; i++)
    {
        free(*(p + i));
    }
}

void alloc()
{
    int **p = (int **)malloc(3 * sizeof(int *));
    p_init(p);
    p_free(p);
    free(p);
}

int main()
{
    alloc();
    Frama_C_dump_each();
    alloc(); // No reuse because weak base was allocated in the first call and it is not included in the input state of the second call
}