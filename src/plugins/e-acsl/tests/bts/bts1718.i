/* run.config
   COMMENT: bts #1718, issue regarding incorrect initialization of literal strings in global arrays with compound initializers
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\""
   EXECNOW: LOG gen_bts1718.c BIN gen_bts1718.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/bts/bts1718.i -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts1718.c > /dev/null && ./gcc_bts.sh bts1718
   EXECNOW: LOG gen_bts17182.c BIN gen_bts17182.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/bts/bts1718.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts17182.c > /dev/null && ./gcc_bts.sh bts17182
*/

int main(void) {
  int a = 10, *p;
  goto lbl_1;

 lbl_2:
  /*@ assert \valid(p); */
  return 0;

 lbl_1:
  p = &a;
  goto lbl_2;
}
