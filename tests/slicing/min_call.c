/* run.config
   DEPS: select_return.i
   LIBS: ../libSelect
   MODULE: @PTEST_NAME@
   OPT: @EVA_OPTIONS@ -deps -lib-entry -main g -journal-disable -slicing-level 3
*/

/* dummy source file in order to test minimal calls feature
 * on select_return.i  */
#include "select_return.i"
