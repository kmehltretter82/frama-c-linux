/* run.config
   COMMENT: integer constant + a stmt after the assertion
   COMMENT: waiting for fixing BTS #745
   EXECNOW: LOG gen_integer_constant.c BIN gen_integer_constant.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/integer_constant.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_integer_constant.c > /dev/null && gcc -pedantic -Wno-long-long -o ./tests/e-acsl-runtime/result/gen_integer_constant.out ./tests/e-acsl-runtime/result/gen_integer_constant.c -lgmp && ./tests/e-acsl-runtime/result/gen_integer_constant.out
*/
int main(void) {
  int x;
  /*@ assert 0 == 0; */ x = 0;
  /*@ assert 0 != 1; */
  /*@ assert 1152921504606846975 == 0xfffffffffffffff; */

  /* /\*@ assert 0xffffffffffffffffffffffffffffffff == 0xffffffffffffffffffffffffffffffff; *\/ */

  return 0;
}
