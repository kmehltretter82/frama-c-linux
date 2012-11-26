/* run.config
   COMMENT: argument of functions must be kept, so keep its parameter
   EXECNOW: LOG gen_bts1304.c BIN gen_bts1304.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1304.i -constfold -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts1304.c > /dev/null && ./gcc_test.sh bts1304
   EXECNOW: LOG gen_bts13042.c BIN gen_bts13042.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1304.i -constfold -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts13042.c > /dev/null && ./gcc_test.sh bts13042
*/

struct msgA { int type; int a[2]; };
struct msgB { int type; double x; };
union msg {
  struct { int type; } T;
  struct msgA A;
  struct msgB B;
};

void read_sensor_4(unsigned* m) {
  /* put 4 bytes from sensors into m */
  *m = 0;
}

int main(void) {
  unsigned char buf[sizeof(union msg)];
  int i;
  for(i = 0; i < sizeof(buf)/4; i++)
    read_sensor_4((unsigned*)buf+i);
  /*@ assert \initialized((union msg*)buf); */
  return 0;
}
