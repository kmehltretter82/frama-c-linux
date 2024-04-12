/* run.config
  MODULE: @PTEST_NAME@
  STDOPT: -print
*/

void unop(int a) {
  //@ assert -(21 + 21);
  //@ assert ~21;
  //@ assert -a;
}

void binop(int a) {
  //@ assert 21 + 21 + a == 42;
  //@ assert 84 - 42 == 42;
  //@ assert 6 * 7 == 42;
  //@ assert 21 << 1 == 42;
  //@ assert 672 >> 4 == 42;
  //@ assert (58 & 47) == 42;
  //@ assert (34 | 8) == 42;
  //@ assert (63 ^ 21) == 42;
  //@ assert 168 / 4 == 42;
}
