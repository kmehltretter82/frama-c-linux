/* run.config
   COMMENT: variadic function call
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\""
   EXECNOW: LOG gen_bts1398.c BIN gen_bts1398.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/bts/bts1398.c -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts1398.c > /dev/null && ./gcc_bts.sh bts1398 > /dev/null
   EXECNOW: LOG gen_bts13982.c BIN gen_bts13982.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/bts/bts1398.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts13982.c > /dev/null && ./gcc_bts.sh bts13982 > /dev/null
*/

#include "stdio.h"

int main(void) {
  int x = 0, t[2];
  int i = 1;
  t[0] = 1;
  t[1] = 2;
  printf("X=%d, t[0]=%d, t[1]=%d\n", x, t[0], t[i]);
}
