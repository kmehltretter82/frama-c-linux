/* run.config
   DONTRUN: main test is in ast_diff_1.i
*/
int X;
int Y=4;

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
  static int y = 0;
  y++;
  return y;
}

int used_in_decl;

int decl() {
  used_in_decl++;
  return used_in_decl;
}

/*@ type nat = Zero | Succ(nat); */
