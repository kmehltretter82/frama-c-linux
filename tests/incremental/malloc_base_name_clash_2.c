/* run.config
      DONTRUN: main test is in malloc_base_name_clash_1.c
      COMMENT: To make line corresponds to the one in malloc_base_name_clash_1.c
      COMMENT: To make line corresponds to the one in malloc_base_name_clash_1.c
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
    alloc(3);
}

int main()
{
    foo();
    bar();
    return 0;
}