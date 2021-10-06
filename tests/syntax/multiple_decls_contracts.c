/* run.config
 COMMENT: dependency to FRAMA-C share directory is implicit
 MACRO: LIBC @FRAMAC_SHARE@/libc
 CMD: @frama-c-cmd@ @PTEST_OPTIONS@
  OPT: @LIBC@/string.h @PTEST_FILE@ @PTEST_FILE@ -print
  OPT: @PTEST_FILE@ @LIBC@/string.h @PTEST_FILE@ -print
  OPT: @PTEST_FILE@ @PTEST_FILE@ @LIBC@/string.h -print
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
