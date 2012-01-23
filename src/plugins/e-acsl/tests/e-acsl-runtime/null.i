/* run.config
   COMMENT: assert \null == 0
   EXECNOW: LOG gen_null.c BIN gen_null.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/null.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_null.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_null.out ./tests/e-acsl-runtime/result/gen_null.c -lgmp && ./tests/e-acsl-runtime/result/gen_null.out
   EXECNOW: LOG gen_null2.c BIN gen_null2.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/null.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_null2.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_null2.out ./tests/e-acsl-runtime/result/gen_null2.c -lgmp && ./tests/e-acsl-runtime/result/gen_null2.out
*/

int main(void) {
  /*@ assert \null == 0; */
  return 0;
}
