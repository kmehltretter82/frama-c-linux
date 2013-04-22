/* run.config
   COMMENT: bts #1390, issue with typing of quantified variables
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\""
   EXECNOW: LOG gen_bts1390.c BIN gen_bts1390.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1390.c -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts1390.c > /dev/null && ./gcc_test.sh bts1390
   EXECNOW: LOG gen_bts13902.c BIN gen_bts13902.out @frama-c@ -cpp-extra-args="-I`@frama-c@ -print-share-path`/libc" -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1390.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts13902.c > /dev/null && ./gcc_test.sh bts13902
*/

#include "stdlib.h"

/*@ behavior exists:
  assumes \exists integer i; 0 <= i < n && ((char*)buf)[i] == c;
  ensures
  \forall int i; 0 <= i < \offset((char*)\result) ==> ((char*)buf)[i] != c; 
  behavior not_exists:
  assumes \forall integer i; 0 <= i < n ==> ((char*)buf)[i] != c;
  ensures \result == (void*) 0; */
void *memchr(const void *buf, int c, size_t n) {
  int i;
  char *s = buf;
  for(i = 0; i < n; i++) {
    if(*s == c) return s;
    s++;
  }
  return (void*)0;
}

int main(void) {
  memchr("toto", 'o', 4);
  memchr("toto", 'a', 4);
  return 0;
}
