/* run.config
   COMMENT: predicate using lazy operators
   EXECNOW: LOG gen_lazy.c BIN gen_lazy.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/lazy.i -e-acsl-project p -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_lazy.c > /dev/null &&  gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_lazy.out ./tests/e-acsl-runtime/result/gen_lazy.c -lgmp 2> /dev/null && ./tests/e-acsl-runtime/result/gen_lazy.out
*/

int main(void) {
  int x = 0, y = 1;
  /*@ assert x == 0 && y == 1; */
  /*@ assert ! (x != 0 && y == 1/0); */
  /*@ assert y == 1 || x == 1; */
  /*@ assert x == 0 || y == 1/0; */
  /*@ assert x == 0 ==> y == 1; */
  /*@ assert x == 1 ==> y == 1/0; */
  return 0;
}
