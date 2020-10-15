/* run.config*
   PLUGIN: metrics @EVA_CONFIG@
   OPT: -eva-no-builtins-auto @EVA_OPTIONS@ %{read:../../syntax/framac_share_path}/libc/string.c -eva -eva-slevel 6 -metrics-eva-cover -then -metrics-libc
*/

#include "string.h"

void main() {
  char *s = "blabli";
  int l = strlen(s);
}
