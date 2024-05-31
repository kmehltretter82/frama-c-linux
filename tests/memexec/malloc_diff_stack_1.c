/* run.config*
   OPT: -eva @EVA_CONFIG@ -eva-no-alloc-returns-null -eva-msg-key=alloc-summary,malloc,memexec,memexec-malloc -eva-mlevel 2
*/

#include <stdlib.h>

int *alloc()
{
    int *p = (int *)malloc(sizeof(int));
    *p = 42;
    return p;
}

// We only save and potentially reuse the last allocated base for efficiency
int main()
{
    int *a = alloc(); // Allocate and save
    int *b = alloc(); // Allocate and overwrite the base saved by previous call
    int *c = alloc(); // Allocate and overwrite the base saved by previous call
    free(a);
    free(b);
    free(c);
    int *d = alloc(); // Reuse the base saved by previous call to alloc
    int *e = alloc(); // Allocate and overwrite the base saved by previous call
    int *f = alloc(); // Allocate and overwrite the base saved by previous call
    free(d);
    free(e);
    free(f);
    return 0;
}
