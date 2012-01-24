/* run.config
   COMMENT: quantifiers
   EXECNOW: LOG gen_quantif.c BIN gen_quantif.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/quantif.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_quantif.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_quantif.out ./tests/e-acsl-runtime/result/gen_quantif.c -lgmp && ./tests/e-acsl-runtime/result/gen_quantif.out
   EXECNOW: LOG gen_quantif2.c BIN gen_quantif2.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/quantif.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_quantif2.c > /dev/null && gcc -pedantic -Wno-long-long -o ./tests/e-acsl-runtime/result/gen_quantif2.out ./tests/e-acsl-runtime/result/gen_quantif2.c -lgmp && ./tests/e-acsl-runtime/result/gen_quantif2.out
*/

int main(void) {

  // simple universal quantifications

  /*@ assert \forall integer x; 0 <= x <= 1 ==> x == 0 || x == 1; */
  /*@ assert \forall integer x; 0 < x <= 1 ==> x == 1; */
  /*@ assert \forall integer x; 0 < x < 1 ==> \false; */
  /*@ assert \forall integer x; 0 <= x < 1 ==> x == 0; */

  /* // multiple universal quantifications */

  /*@ assert \forall integer x,y,z; 0 <= x < 2 && 0 <= y < 5 && 0 <= z <= y
    ==> x+z <= y+1; */

  // simple existential quantification

  /*@ assert \exists int x; 0 <= x < 10 && x == 5; */

  // mixed universal and existential quantifications

  /*@ assert \forall int x; 0 <= x < 10
    ==> x % 2 == 0 ==> \exists integer y; 0 <= y <= x/2 && x == 2 * y; */

  return 0;
}
