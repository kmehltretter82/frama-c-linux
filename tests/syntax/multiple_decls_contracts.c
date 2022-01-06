/* run.config
OPT: @PTEST_SHARE_DIR@/libc/string.h @PTEST_FILE@ @PTEST_FILE@ -cpp-extra-args="-I@PTEST_SHARE_DIR@/libc" -print
OPT: @PTEST_FILE@ @PTEST_SHARE_DIR@/libc/string.h @PTEST_FILE@ -cpp-extra-args="-I@PTEST_SHARE_DIR@/libc" -print
OPT: @PTEST_FILE@ @PTEST_FILE@ @PTEST_SHARE_DIR@/libc/string.h -cpp-extra-args="-I@PTEST_SHARE_DIR@/libc" -print
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
