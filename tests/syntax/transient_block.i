/* run.config
<<<<<<< HEAD
   MODULE: @PTEST_NAME@
   STDOPT: +"-no-print" +"-kernel-warn-key transient-block=active"
||||||| 754e522ceb
   EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
   OPT: -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -kernel-warn-key transient-block=active
=======
 MODULE: @PTEST_NAME@
   OPT: -kernel-warn-key transient-block=active
>>>>>>> origin/master
*/

void f(void) { }

int main () {

  int x = 1;
  x = 2;
  f();

}
