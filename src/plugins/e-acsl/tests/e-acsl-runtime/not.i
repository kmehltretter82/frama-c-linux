/* run.config
   COMMENT: predicate [!p]
   EXECNOW: LOG gen_not.c BIN gen_not.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/not.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_not.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_not.out ./tests/e-acsl-runtime/result/gen_not.c && ./tests/e-acsl-runtime/result/gen_not.out
*/
int main(void) {
  int x = 0;
  /*@ assert ! x; */
  if (x) /*@ assert x; */ ;
  return 0;
}
