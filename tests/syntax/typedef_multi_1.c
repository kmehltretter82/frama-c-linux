/* run.config
<<<<<<< HEAD
   DEPS: typedef_multi.h
   MODULE: typedef_multi
   STDOPT: +"-no-print" +"%{dep:typedef_multi_2.c}"
||||||| 754e522ceb
   EXECNOW: make -s @PTEST_DIR@/typedef_multi.cmxs
   OPT: -load-module @PTEST_DIR@/typedef_multi tests/syntax/typedef_multi_2.c
=======
 MODULE: typedef_multi
 DEPS: typedef_multi.h
   OPT: -no-autoload-plugins %{dep:@PTEST_DIR@/typedef_multi_2.c}
>>>>>>> origin/master
*/
#include "typedef_multi.h"

void f () {  while(x<y) x++; }
