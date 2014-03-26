/* run.config
   COMMENT: bts #1717, issue with labels on memory-related statements
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\""
   EXECNOW: LOG gen_bts1717.c BIN gen_bts1717.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1717.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts1717.c > /dev/null && ./gcc_test.sh bts1717
   EXECNOW: LOG gen_bts17172.c BIN gen_bts17172.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1717.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts17172.c > /dev/null && ./gcc_test.sh bts17172
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
