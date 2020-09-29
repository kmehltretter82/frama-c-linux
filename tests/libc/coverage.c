/* run.config*
   PLUGIN: metrics
   DEPS: ../../../share/libc/string.c
   OPT: -eva-no-builtins-auto @EVA_OPTIONS@ ../../../share/libc/string.c -eva -eva-slevel 6 -metrics-eva-cover -then -metrics-libc
*/

#include "string.h"

void main() {
  char *s = "blabli";
  int l = strlen(s);
}
