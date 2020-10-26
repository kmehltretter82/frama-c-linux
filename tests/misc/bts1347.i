/* run.config
   PLUGIN: report @EVA_CONFIG@
   MODULE: @PTEST_NAME@
   OPT:  @EVA_OPTIONS@ -then -report
*/
int f(int *x) { return *x; }
int g(int *x) { return *(x++); }
