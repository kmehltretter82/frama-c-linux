/* run.config
   LIBS: libSelect
   CMXS: @PTEST_NAME@
   CMD: @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs} @OPTIONS@
   OPT: @EVA_OPTIONS@ -deps -lib-entry -main g -journal-disable -slicing-level 3
*/

/* dummy source file in order to test minimal calls feature
 * on select_return.c  */

#include "select_return.c"
