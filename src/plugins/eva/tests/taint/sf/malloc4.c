/* run.config
   COMMENT: Test dynamic allocation and branching
   DEPS: security_calloc.h
   STDOPT: #"-eva-no-alloc-returns-null" +"-eva-verbose 0 -eva-no-alloc-returns-null"
 */
#include <stdlib.h>
#include "security_calloc.h"

extern int __fc_private secret;

int main(void) {
    int *p = NULL;

    if (secret) {
        p = malloc(sizeof *p);
        *p = secret;
    } else {
        // do nothing
    }

    free(p);

    return 0;
}
