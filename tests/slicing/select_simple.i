/* run.config

   CMD: @frama-c@ -load-module %{dep:libSelect.cmxs} -load-module %{dep:@PTEST_NAME@.cmxs}
   OPT: @EVA_OPTIONS@ -deps -journal-disable
*/

/* dummy source file in order to test select_simple.ml */

#include "simple_intra_slice.c"
