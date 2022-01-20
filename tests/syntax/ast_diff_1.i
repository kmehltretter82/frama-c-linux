/* run.config
   MODULE: @PTEST_NAME@
     OPT: -then -ast-diff ast_diff_2.i
*/
int X;
int Y=3;

int f(int x) {
  if (x <= 0)
    X = 0;
  else
    X = x;
  return X;
}

/*@ requires Y > 0;
    ensures X > 0;
    assigns X;
*/
int g() {
  X = Y;
  return X;
}

/*@ requires X > 0;
    ensures X > 0;
    assigns X;
*/
int h() {
  if (Y > 0)
    X = Y;
  return Y;
}
