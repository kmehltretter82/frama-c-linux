/* run.config
   COMMENT: assert \null == 0
   EXECNOW: LOG gen_null.c BIN gen_null.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/null.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_null.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_null.out ./tests/e-acsl-runtime/result/gen_null.c -lgmp && ./tests/e-acsl-runtime/result/gen_null.out
*/

int main(void) {
  /*@ assert \null == 0; */
  return 0;
}
