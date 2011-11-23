/* run.config
   COMMENT: \at
   EXECNOW: LOG gen_at.c BIN gen_at.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/at.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_at.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_at.out ./tests/e-acsl-runtime/result/gen_at.c -lgmp && ./tests/e-acsl-runtime/result/gen_at.out
*/

int main(void) {

  int x;

  x = 0;
 L: /*@ assert x == 0; */ x = 1;
  x = 2;

  /*@ assert \at(x,L) == 0; */
  /*@ assert \at(x+1,L) == 1; */
  /*@ assert \at(x,L)+1 == 1; */

  return 0;
}
