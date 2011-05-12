/* run.config
   COMMENT: non integer constants
   EXECNOW: LOG gen_other_constants.c BIN gen_other_constants.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/other_constants.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_other_constants.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_other_constants.out -lgmp ./tests/e-acsl-runtime/result/gen_other_constants.c && ./tests/e-acsl-runtime/result/gen_other_constants.out
*/

enum bool { false, true };

int main(void) {
  /*@ assert "toto" != "titi"; */
  /*@ assert 'c' == 'c'; */
  /*@ assert false != true; */
  return 0;
}
