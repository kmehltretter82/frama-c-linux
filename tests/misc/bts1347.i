/* run.config
   PLUGIN: report
   MODULE: @PTEST_NAME@.cmxs
   OPT:  @EVA_OPTIONS@ -then -report
*/
int f(int *x) { return *x; }
int g(int *x) { return *(x++); }
