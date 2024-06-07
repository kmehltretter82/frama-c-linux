/* run.config
      DONTRUN: main test is in loop_reuse_malloc_1.c
      COMMENT: To make line corresponds to the one in loop_reuse_malloc_1.c
      COMMENT: To make line corresponds to the one in loop_reuse_malloc_1.c
*/
#include <stdlib.h>

int a;

void *alloc()
{
    int *p = malloc(sizeof(int));
    *p = 0;
    return p;
}

void init_p(int **arr) // Malloced function, no widening reuse
{
    a++;
    for (int i = 0; i < 3; i++)
    {
        *(arr + i) = alloc();
    }
}

void free_p(int **arr) // Cacheable function, widening reuse
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
    a = 1;
    loop();
}