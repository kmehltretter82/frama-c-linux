/* run.config
   COMMENT: invariant
   EXECNOW: LOG gen_invariant.c BIN gen_invariant.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/invariant.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_invariant.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_invariant.out ./tests/e-acsl-runtime/result/gen_invariant.c -lgmp && ./tests/e-acsl-runtime/result/gen_invariant.out
   EXECNOW: LOG gen_invariant2.c BIN gen_invariant2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/invariant.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_invariant2.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_invariant2.out ./tests/e-acsl-runtime/result/gen_invariant2.c -lgmp && ./tests/e-acsl-runtime/result/gen_invariant2.out
*/
int main(void) {
  int x = 0;
  for(int i = 0; i < 10; i++) {
    /*@ invariant 0 <= i < 10; */
    x += i;
    /*@ invariant i <= x; */
  }
  return 0;
}
