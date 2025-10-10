// Value's builtin for calloc is a work in progress (see Frama-C MR 1078),
// so fake it for now by providing an implementation that calls malloc and
// memset directly. Once Value provides a proper builtin for calloc, this
// entire file can be removed.

#ifndef SECURITY_CALLOC_H
#define SECURITY_CALLOC_H

#include <stdlib.h>

// Do not include <string.h> for memset to avoid including even more unused
// prototypes in the tests' output. This small stub contract is enough for
// our tests.
/*@ assigns \result \from s;
    assigns ((char *) s)[0..n-1] \from c, n;
 */
void *memset(void *s, int c, size_t n);

#endif
