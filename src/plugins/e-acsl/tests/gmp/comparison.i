/* run.config
   COMMENT: comparison operators
   COMMENT: no diff
   EXECNOW: LOG gen_comparison2.c BIN gen_comparison2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/gmp/comparison.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/gmp/result/gen_comparison2.c > /dev/null && ./gcc_runtime.sh comparison2
*/

int main(void) {
  int x = 0, y = 1;
  /*@ assert x < y; */
  /*@ assert y > x; */
  /*@ assert x <= 0; */
  /*@ assert y >= 1; */
  char *s = "toto";
  /*@ assert s == s; */
  // waiting for clarification of semantics of ACSL's literal strings
  //  /*@ assert "toto" != "titi"; */
  /*@ assert 5 < 18; */
  /*@ assert 32 > 3; */
  /*@ assert 12 <= 13; */
  /*@ assert 123 >= 12; */
  /*@ assert 0xff == 0xff; */
  /*@ assert 1 != 2; */

  /*@ assert -5 < 18; */
  /*@ assert 32 > -3; */
  /*@ assert -12 <= 13; */
  /*@ assert 123 >= -12; */
  /*@ assert -0xff == -(+0xff); */
  /*@ assert +1 != -2; */
  return 0;
}
