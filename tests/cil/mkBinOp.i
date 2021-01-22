/* run.config
MODULE: @PTEST_NAME@
STDOPT: +"-machdep x86_32 -constfold"
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
