/* run.config
   COMMENT: predicate [!p]
   COMMENT: no diff
   EXECNOW: LOG gen_not2.c BIN gen_not2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/gmp/not.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/gmp/result/gen_not2.c > /dev/null && ./gcc_runtime.sh not2
*/
int main(void) {
  int x = 0;
  /*@ assert ! x; */
  if (x) /*@ assert x; */ ;
  return 0;
}
