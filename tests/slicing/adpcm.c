/* run.config
   DEPS: ../../test/adpcm.c
   STDOPT: +"-add-symbolic-path TESTS_DIR:../.. -load-module %{dep:libSelect.cmxs} -load-module %{dep:@PTEST_NAME@.cmxs} -ulevel -1 -deps -slicing-level 2 -journal-disable"
*/

#include "../../test/adpcm.c"
