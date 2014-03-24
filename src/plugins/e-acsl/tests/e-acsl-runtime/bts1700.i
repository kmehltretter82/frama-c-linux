/* run.config
   COMMENT: pointer to an empty struct
   EXECNOW: LOG gen_bts1700.c BIN gen_bts1700.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1700.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts1700.c > /dev/null && ./gcc_test.sh bts1700
*/

struct toto {};

int main() {
  struct toto s;
  //@ assert \valid(&s);
  struct toto *p;
  p = &s;
  //@ assert \valid(p);
  return 0;
}
