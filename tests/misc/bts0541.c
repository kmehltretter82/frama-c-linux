/* run.config
 MACRO: LIBC @FRAMAC_SHARE@/LIBC
   OPT: -pp-annot -cpp-extra-args="-I@LIBC@" -pp-annot -eva @EVA_OPTIONS@
*/
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

int main() {

  _Bool x = true;
  /*@ assert x==false ==> \false; */
  return 0;

}
