/* run.config
CMD: frama-c @DEFAULT_OPTIONS@ @PLUGIN_OPTIONS@ @OPTIONS@
OPT: %{read:../framac_share_path}/libc/string.h @PTEST_FILE@ @PTEST_FILE@ -print
OPT: @PTEST_FILE@ %{read:../framac_share_path}/libc/string.h @PTEST_FILE@ -print
OPT: @PTEST_FILE@ @PTEST_FILE@ %{read:../framac_share_path}/libc/string.h -print
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
