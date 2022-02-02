/* run.config
<<<<<<< HEAD
MODULE: @PTEST_NAME@
STDOPT: +"%{dep:@PTEST_NAME@_1.i}"
||||||| 754e522ceb
EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -print -no-autoload-plugins -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs @PTEST_DIR@/@PTEST_NAME@_1.i
=======
 MODULE: @PTEST_NAME@
   OPT: -print -no-autoload-plugins @PTEST_DIR@/@PTEST_NAME@_1.i
>>>>>>> origin/master
*/

void f(int x);

void g() { f(3); }
