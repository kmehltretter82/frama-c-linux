/* run.config*
   OPT: -eva @EVA_CONFIG@ -out-external -input -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2
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

void test(void (*f)())
{
    f();
}

int main()
{
    void (*f)() = foo;
    void (*g)() = foo;

    test(f);
    test(g);

    return 0;
}
