/* run.config
   COMMENT: assert \true
   EXECNOW: LOG gen_true.c BIN gen_true.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/true.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_true.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_true.out ./tests/e-acsl-runtime/result/gen_true.c && ./tests/e-acsl-runtime/result/gen_true.out
*/
int main(void) {
  int x = 0;
  //  /*@ assert \true == 0; */ // not yet implemented
  /*@ assert \true; */
  return 0;
}
