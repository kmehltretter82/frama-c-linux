/* run.config*
 MACRO: machdep %{dep:@PTEST_DIR@/@PTEST_NAME@.yaml}
 OPT: -machdep @machdep@ -print
 COMMENT: we can't only use -D, as the __fc_machdep.h define takes precedence
 COMMENT: with -U, our cmdline definition is used in the code
 OPT: -machdep @machdep@ -cpp-extra-args="-UCUSTOM_MACHDEP -DCUSTOM_MACHDEP=42" -print
*/
// most of the following includes are not directly used, but they test if
// the custom machdep has defined the necessary constants
#include <ctype.h>
#include <inttypes.h>
#include <limits.h>
#include <locale.h>
#include <math.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <wchar.h>

int main() { return INT_MAX - CUSTOM_MACHDEP; }
