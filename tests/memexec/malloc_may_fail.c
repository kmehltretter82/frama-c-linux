
/* run.config*
   OPT: -eva @EVA_CONFIG@ -out-external -input -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2
*/

#include <stdlib.h>
#include <__fc_builtin.h>

void *alloc(size_t size)
{

    if (size == 0)
    {
        return NULL;
    }
    void *buf = malloc(size);
    if (buf == NULL)
    {
        exit(1);
    }
    return buf;
}

void foo(int arg)
{
    int size = Frama_C_interval(0, 1);
    int *p = (int *)alloc(sizeof(int) * size);
    Frama_C_dump_each();

    //@ loop unroll 3;
    for (int i = 0; i < 3; i++)
    {
        int *q = (int *)alloc(sizeof(int) * size); // Reuse allocated base
        Frama_C_dump_each();
        *q = i;
        free(q);
    }
    free(p);
    Frama_C_dump_each();
}

int main(int argc, char const *argv[])
{
    foo(1);
    foo(2);
    foo(3);
    foo(2);
}
