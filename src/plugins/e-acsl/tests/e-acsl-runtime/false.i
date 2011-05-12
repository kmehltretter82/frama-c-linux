/* run.config
   COMMENT: assert \false
   EXECNOW: LOG gen_false.c BIN gen_false.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/false.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_false.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_false.out ./tests/e-acsl-runtime/result/gen_false.c && ./tests/e-acsl-runtime/result/gen_false.out
*/
int main(void) {
  int x = 0;
  if (x) /*@ assert \false; */ ;
  return 0;
}
