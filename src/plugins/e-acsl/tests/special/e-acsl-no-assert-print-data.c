/* run.config
   COMMENT: test assertion failure without printing assertion data

   STDOPT: #"-e-acsl-O-no-print-values"
*/
/* run.config_dev
   MACRO: ROOT_EACSL_GCC_FC_EXTRA_EXT -e-acsl-O-no-print-values
*/

#include <limits.h>

int main() {
  int value = INT_MAX;
  //@ check \let x = value; \false;
  return 0;
}
