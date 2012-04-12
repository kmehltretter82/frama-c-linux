/* run.config
   COMMENT: predicate [!p]
   EXECNOW: LOG gen_not.c BIN gen_not.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/not.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_not.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_not.out ./tests/e-acsl-runtime/result/gen_not.c && ./tests/e-acsl-runtime/result/gen_not.out
   EXECNOW: LOG gen_not2.c BIN gen_not2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/not.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_not2.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_not2.out ./tests/e-acsl-runtime/result/gen_not2.c -lgmp && ./tests/e-acsl-runtime/result/gen_not2.out
*/
int main(void) {
  int x = 0;
  /*@ assert ! x; */
  if (x) /*@ assert x; */ ;
  return 0;
}
