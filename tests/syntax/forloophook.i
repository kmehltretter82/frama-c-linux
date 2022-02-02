/* run.config
<<<<<<< HEAD
   MODULE: @PTEST_NAME@
   STDOPT: +"-no-print"
||||||| 754e522ceb
   EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
   OPT: -no-autoload-plugins -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs
=======
 MODULE: @PTEST_NAME@
   OPT: -no-autoload-plugins
>>>>>>> origin/master
*/
void f() {
  for (int i=0; i< 10; i++);
}
