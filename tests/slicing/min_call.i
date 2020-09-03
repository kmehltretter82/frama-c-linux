/* run.config

   CMD: @frama-c@ -load-plugin slicing -load-module %{dep:libSelect.cmxs} -load-module %{dep:@PTEST_NAME@.cmxs}
   OPT: @EVA_OPTIONS@ -deps -lib-entry -main g -journal-disable -slicing-level 3
*/

/* dummy source file in order to test minimal calls feature
 * on select_return.c  */

#include "select_return.c"
