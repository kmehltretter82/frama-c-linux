/* run.config
   COMMENT: fixed bug with typing of universal quantification
   EXECNOW: LOG gen_bts1324.c BIN gen_bts1324.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1324.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts1324.c > /dev/null && ./gcc_test.sh bts1324
   EXECNOW: LOG gen_bts13242.c BIN gen_bts13242.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1324.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts13242.c > /dev/null && ./gcc_test.sh bts13242
*/

/*@ behavior yes:
  @   assumes \forall int i; 0 < i < n ==> t[i-1] <= t[i];
  @   ensures \result == 1;
  @*/
int sorted(int * t, int n) {
  int b = 1;
  if(n <= 1)
    return 1;
  for(b = 1; b < n; b++) {
    if(t[b-1] > t[b])
      return 0;
  }
  return 1;
}

int main(void) {
  int t[7] = { 1, 4, 4, 5, 5, 5, 7 };
  int n = sorted(t, 7);
  /*@ assert n == 1; */
  return 0;
}
