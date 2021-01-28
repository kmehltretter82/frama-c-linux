/* run.config
<<<<<<< HEAD
MODULE: @PTEST_NAME@
STDOPT: +"-machdep x86_32 -constfold"
||||||| ac7807782d
EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -no-autoload-plugins -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -print -constfold
=======
EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -machdep x86_32 -no-autoload-plugins -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -print -constfold
>>>>>>> origin/master
*/

int main(void) {
  /* test Cil.constFoldBinOp called by mkBinOp for '%':
     the sign of the result is the sign of the divident */
  int res = 3 % 2 == -1; // 0
  res = 3 % -2 == -1;    // 0
  res = -3 % 2 == 1;     // 0
  res = -3 % -2 == 1;    // 0
  return res;
}
