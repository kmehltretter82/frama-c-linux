/* run.config*
   OPT: -eva @EVA_CONFIG@ -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2
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
    bar(); // Reuse the base
    bar(); // Reuse the base
    return 0;
}
