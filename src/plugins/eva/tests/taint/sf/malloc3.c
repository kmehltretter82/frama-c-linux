/* run.config
   COMMENT: Test dynamic allocation and branching
   DEPS: security_calloc.h
   STDOPT: #"-eva-slevel 3 -eva-no-alloc-returns-null" +"-eva-verbose 0 -eva-slevel 3 -eva-no-alloc-returns-null"
 */
#include <stdlib.h>
#include "security_calloc.h"

extern int __fc_private secret;

int main(void) {
    int *p = NULL, *q = NULL;

    if (secret < 0) {
        p = malloc(sizeof *p);
    } else if (secret > 0) {
        p = malloc(sizeof *p);
    } else {
        q = malloc(sizeof *q);
    }

    /*@ assert security_status(p) == private; */
    /*@ assert security_status(q) == private; */

    // In the assignments below, only one of [p] or [q] is allocated, but we
    // must still be able to modify the other's target's summary label.
    // Additionally, [p] may have been allocated at one of two different
    // call sites. The transformation introduces a statically allocated
    // summary per [malloc] call site to handle all this.
    if (secret) {
        *p = 1;
    } else {
        *q = 2;
    }

    free(p);
    free(q);

    return 0;
}
