/* run.config
<<<<<<< HEAD
DONTRUN: main test is located in formals_decl_leak.i
||||||| 754e522ceb
DONTRUN: main test is located in tests/syntax/formals_decl_leak.i
=======
DONTRUN: main test is located in @PTEST_DIR@/formals_decl_leak.i
>>>>>>> origin/master
*/

void f(int y);

void h () { f(4); }
