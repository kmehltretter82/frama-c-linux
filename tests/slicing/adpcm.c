/* run.config
 MODULE: @PTEST_NAME@
 CMD: @frama-c@ -load-module tests/slicing/libSelect.cmxs
   OPT: @EVA_OPTIONS@ -machdep x86_32 -ulevel -1 -deps -slicing-level 2 -journal-disable
*/

#include "../test/adpcm.c"
