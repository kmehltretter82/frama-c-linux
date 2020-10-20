/* run.config
   LIBS: libSelect
   CMXS: @PTEST_NAME@
   DEPS: ../../test/adpcm.c
   STDOPT: +"-add-symbolic-path TESTS_DIR:../.. -load-module %{dep:@PTEST_NAME@.cmxs} -ulevel -1 -deps -slicing-level 2 -journal-disable"
*/

#include "../../test/adpcm.c"
