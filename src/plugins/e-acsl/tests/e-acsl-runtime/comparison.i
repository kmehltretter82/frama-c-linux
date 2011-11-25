/* run.config
   COMMENT: comparison operators
   EXECNOW: LOG gen_comparison.c BIN gen_comparison.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/comparison.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_comparison.c > /dev/null &&  gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_comparison.out ./tests/e-acsl-runtime/result/gen_comparison.c -lgmp && ./tests/e-acsl-runtime/result/gen_comparison.out
*/

int main(void) {
  int x = 0, y = 1;
  /*@ assert x < y; */
  /*@ assert y > x; */
  /*@ assert x <= 0; */
  /*@ assert y >= 1; */
  char *s = "toto";
  /*@ assert s == s; */
  /*@ assert "toto" != "titi"; */
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
