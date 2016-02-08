/* run.config
   COMMENT: arrays
   STDOPT: #"-slevel 5"
   COMMENT: no diff
   EXECNOW: LOG gen_array2.c BIN gen_array2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/gmp/array.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/gmp/result/gen_array2.c > /dev/null && ./gcc_runtime.sh array2
*/

int T1[3],T2[4];

int main(void) {

  for(int i = 0; i < 3; i++) T1[i] = i;
  for(int i = 0; i < 4; i++) T2[i] = 2*i;

  /*@ assert T1[0] == T2[0]; */
  /*@ assert T1[1] != T2[1]; */

  return 0;
}
