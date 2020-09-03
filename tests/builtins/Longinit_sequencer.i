/* run.config*
   CMXS: @PTEST_NAME@
   DEPS: long_init.c long_init2.c long_init3.c
   OPT: @EVA_OPTIONS@ -load-module %{dep:@PTEST_NAME@.cmxs} -res-file @PTEST_RESULT@
*/
