/* run.config
   COMMENT: \at
   EXECNOW: LOG gen_at.c BIN gen_at.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/at.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_at.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_at.out ./tests/e-acsl-runtime/result/gen_at.c -lgmp
*/

int A = 0;

/*@ ensures \at(A,Post) == 3; */
void f(void) {
  A = 1;
 F: A = 2;
  /*@ assert \at(A,Pre) == 0; */
  /*@ assert \at(A,F) == 1; */
  /*@ assert \at(A,Here) == 2; */
  /*@ assert \at(\at(A,Pre),F) == 0; */
  A = 3;
}

int main(void) {

  int x;

  x = 0;
 L: /*@ assert x == 0; */ x = 1;
  x = 2;

  f();

  /*@ assert \at(x,L) == 0; */
  /*@ assert \at(x+1,L) == 1; */
  /*@ assert \at(x,L)+1 == 1; */

  return 0;
}
