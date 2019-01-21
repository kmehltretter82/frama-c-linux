/* run.config
   EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
   OPT: -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs
*/
void f() {
  for (int i=0; i< 10; i++);
}
