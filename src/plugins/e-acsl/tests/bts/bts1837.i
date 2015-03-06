/* run.config
   COMMENT: bts #1837, about initialization of literal strings
   EXECNOW: LOG gen_bts1837.c BIN gen_bts1837.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1837.i -e-acsl -then-last -print -ocode ./tests/bts/result/gen_bts1837.c > /dev/null && ./gcc_bts.sh bts1837
*/

char *S = "foo";

int f(void) {
  char *s1 = "foo";
  char *s2 = "bar";
  /*@ assert \valid_read(S); */
  /*@ assert \valid_read(s1); */
  /*@ assert \valid_read(s2); */
  return 0;
}

int main(void) {
  int i = 4;
  while (i--) {
    char *s = "toto";
    /*@ assert \valid_read(s) ; */
    /*@ assert !\valid(s) ; */
  }
  f();
}
