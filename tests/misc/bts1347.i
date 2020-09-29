/* run.config
   PLUGIN: report
   CMXS: @PTEST_NAME@
   OPT:  @EVA_OPTIONS@ -load-module %{dep:@PTEST_NAME@.cmxs} -then -report
*/
int f(int *x) { return *x; }
int g(int *x) { return *(x++); }
