/* run.config
 MODULE: @PTEST_NAME@
 CMD: @frama-c@ -load-module tests/slicing/libSelect.cmxs
   OPT: @EVA_OPTIONS@ -deps -journal-disable
*/

/* dummy source file in order to test select_simple.ml */

#include "simple_intra_slice.i"
