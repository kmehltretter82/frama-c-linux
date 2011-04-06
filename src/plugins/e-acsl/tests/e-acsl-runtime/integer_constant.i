/* run.config
   COMMENT: integer constant
   COMMENT: waiting for fixing BTS #745
   EXECNOW: LOG gen_integer_constant.c BIN gen_integer_constant.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/integer_constant.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_integer_constant.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_integer_constant.out -lgmp ./tests/e-acsl-runtime/result/gen_integer_constant.c
*/
void main() {
  /*@ assert 0 == 0; */
  /*@ assert 0 != 1; */
  /*@ assert 0xfffffffffffffff == 0xfffffffffffffff; */

  /* /\*@ assert 0xffffffffffffffffffffffffffffffff == 0xffffffffffffffffffffffffffffffff; *\/ */
}
