/* run.config
   COMMENT: terms and predicates using lazy operators
   EXECNOW: LOG gen_lazy.c BIN gen_lazy.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/lazy.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_lazy.c > /dev/null &&  gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_lazy.out ./tests/e-acsl-runtime/result/gen_lazy.c -lgmp 2> /dev/null && ./tests/e-acsl-runtime/result/gen_lazy.out
*/

int main(void) {
  int x = 0, y = 1;

  // lazy predicates
  /*@ assert x == 0 && y == 1; */
  /*@ assert ! (x != 0 && y == 1/0); */
  /*@ assert y == 1 || x == 1; */
  /*@ assert x == 0 || y == 1/0; */
  /*@ assert x == 0 ==> y == 1; */
  /*@ assert x == 1 ==> y == 1/0; */
  /*@ assert x ? x : y; */
  /*@ assert y ? y : x; */
  /*@ assert x == 1 ? x == 18 : x == 0; */

  // these predicates are not lazy, but are encoded by lazy ones
  /*@ assert x == 2 <==> y == 3; */
  /*@ assert x == 0 <==> y == 1; */

  // lazy terms
  /*@ assert (x ? x : y) == (x == 0); */
  /*@ assert (x && y) || y; */
  /*@ assert (x || y) && y == 1; */

  return 0;
}
