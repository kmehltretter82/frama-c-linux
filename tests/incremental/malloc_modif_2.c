/* run.config
    DONTRUN: main test is in malloc_modif_1.c
*/
#include <stdlib.h>

void alloc()
{
    int *p = (int *)malloc(sizeof(int));
    free(p);
}

void foo()
{
    int a = 0;
    alloc(); // Call site shifted by one line, call site and function summary (foo) should be imported
}

void bar() //
{
    // alloc(); Call site removed, Call site and function summary (bar) should not be imported
}

int main()
{
    foo();
    bar(); // Call site not imported, calling function summary (main) should not be imported
    return 0;
}