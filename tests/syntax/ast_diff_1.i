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

/*@ requires \is_finite(x);
    requires \is_finite(y);
    assigns \nothing;
    ensures \true != \false;
*/
int use_logic_builtin(double x, float y);

int has_static_local(void) {
  static int x = 0;
  x++;
  return x;
}

int decl(void);

int used_in_decl;

int decl() {
  used_in_decl++;
  return used_in_decl;
}

/*@ type nat = Zero | Succ(nat); */
