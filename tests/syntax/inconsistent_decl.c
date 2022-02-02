/* run.config
<<<<<<< HEAD
EXIT: 1
  STDOPT: +"%{dep:inconsistent_decl_2.i}"
  STDOPT: +"%{dep:inconsistent_decl_2.i}"+"-cpp-extra-args='-DWITH_PROTO'"
||||||| 754e522ceb
STDOPT: +"tests/syntax/inconsistent_decl_2.i"
STDOPT: +"tests/syntax/inconsistent_decl_2.i"+"-cpp-extra-args='-DWITH_PROTO'"
=======
EXIT: 1
  STDOPT: +"@PTEST_DIR@/inconsistent_decl_2.i"
  STDOPT: +"@PTEST_DIR@/inconsistent_decl_2.i"+"-cpp-extra-args='-DWITH_PROTO'"
>>>>>>> origin/master
*/
#ifdef WITH_PROTO
int f();
#endif

int g() {
  int x = f(2);
  return x;
}
