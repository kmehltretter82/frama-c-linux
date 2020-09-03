/* run.config
OPT: string.h @PTEST_FILE@ @PTEST_FILE@ -cpp-extra-args="-Ishare/libc" -print
OPT: @PTEST_FILE@ string.h @PTEST_FILE@ -cpp-extra-args="-Ishare/libc" -print
OPT: @PTEST_FILE@ @PTEST_FILE@ string.h -cpp-extra-args="-Ishare/libc" -print
*/

#include "string.h"
#include "stdlib.h"

char *
strdup(const char *str)
{
    if (str != NULL) {
        register char *copy = malloc(strlen(str) + 1);
        if (copy != NULL)
            return strcpy(copy, str);
    }
    return NULL;
}
