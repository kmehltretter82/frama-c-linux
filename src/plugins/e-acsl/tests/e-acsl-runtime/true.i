/* run.config
   COMMENT: assert \true
   EXECNOW: LOG gen_true.c BIN gen_true.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/true.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_true.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_true.out ./tests/e-acsl-runtime/result/gen_true.c && ./tests/e-acsl-runtime/result/gen_true.out
   EXECNOW: LOG gen_true2.c BIN gen_true2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/true.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_true2.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_true2.out ./tests/e-acsl-runtime/result/gen_true2.c && ./tests/e-acsl-runtime/result/gen_true2.out
*/
int main(void) {
  int x = 0;
  ///*@ assert \true == 0; */ // \true as a term: not yet implemented
  /*@ assert \true; */
  return 0;
}
