/* run.config
   COMMENT: complex term left-values
   EXECNOW: LOG gen_bts1326.c BIN gen_bts1326.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1326.i -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts1326.c > /dev/null && ./gcc_bts.sh bts1326
   EXECNOW: LOG gen_bts13262.c BIN gen_bts13262.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1326.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts13262.c > /dev/null && ./gcc_bts.sh bts13262
*/

typedef int ArrayInt[5];

/*@ ensures
 *AverageAccel == 
 ((*Accel)[4] + (*Accel)[3] + (*Accel)[2] + (*Accel)[1] + (*Accel)[0]) / 5; @*/
void atp_NORMAL_computeAverageAccel(ArrayInt* Accel,int* AverageAccel)
{
  *AverageAccel = 
    ((*Accel)[4] + (*Accel)[3] + (*Accel)[2] + (*Accel)[1] + (*Accel)[0]) / 5;
}

int main(void) {
  ArrayInt Accel = { 1, 2, 3, 4, 5 };
  int av;
  atp_NORMAL_computeAverageAccel(&Accel, &av);
  return 0;
}
