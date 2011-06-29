/* run.config
   COMMENT: arrays
   EXECNOW: LOG gen_array.c BIN gen_array.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/array.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_array.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_array.out -lgmp ./tests/e-acsl-runtime/result/gen_array.c && ./tests/e-acsl-runtime/result/gen_array.out
*/

int T1[3],T2[4];

int main(void) {

  for(int i = 0; i < 3; i++) T1[i] = i;
  for(int i = 0; i < 4; i++) T2[i] = 2*i;

  /*@ assert T1[0] == T2[0]; */
  /*@ assert T1[1] != T2[1]; */

  return 0;
}
