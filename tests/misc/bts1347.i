/* run.config
   EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
   OPT: -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -eva-show-progress -then -report
*/
int f(int *x) { return *x; }
int g(int *x) { return *(x++); }
