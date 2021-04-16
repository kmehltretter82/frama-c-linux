/* run.config
 MODULE: @PTEST_NAME@
 CMD: @frama-c@ -load-module tests/slicing/libSelect.cmxs
   OPT: @EVA_OPTIONS@ -deps -lib-entry -main g -journal-disable -slicing-level 3
*/

/* dummy source file in order to test minimal calls feature
 * on select_return.i  */

#include "select_return.i"
