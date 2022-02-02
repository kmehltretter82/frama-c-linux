/* run.config
<<<<<<< HEAD
DEPS: static_formals.h
STDOPT: +"%{dep:static_formals_2.c}" +"-cpp-extra-args=\"-I @PTEST_DIR@\"" +"-kernel-msg-key printer:vid"
||||||| 754e522ceb
STDOPT: +"@PTEST_DIR@/static_formals_2.c" +"-cpp-extra-args=\"-I @PTEST_DIR@\"" +"-kernel-msg-key printer:vid"
=======
 DEPS: static_formals.h
   STDOPT: +"%{dep:@PTEST_DIR@/static_formals_2.c}" +"-cpp-extra-args=\"-I @PTEST_DIR@\"" +"-kernel-msg-key printer:vid"
>>>>>>> origin/master
*/
#include "static_formals.h"
int g() { return f(4); }
