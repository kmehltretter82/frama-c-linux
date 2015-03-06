/* run.config
   COMMENT: spec with floats and reals
   EXECNOW: LOG gen_bts1307.c BIN gen_bts1307.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1307.i -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts1307.c > /dev/null && ./gcc_test.sh bts1307
   EXECNOW: LOG gen_bts13072.c BIN gen_bts13072.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1307.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts13072.c > /dev/null && ./gcc_test.sh bts13072
*/

/*@ requires \valid(Mtmax_in);
  @ requires \valid(Mwmax);
  @ requires \valid(Mtmax_out);

  @ behavior OverEstimate_Motoring:
  @ assumes \true;
  @ ensures *Mtmax_out == *Mtmax_in + (5 - (((5 / 80) * *Mwmax) * 0.4));
  @*/
void foo(float* Mtmax_in, float* Mwmax, float* Mtmax_out) {
  *Mtmax_out = *Mtmax_in + (5 - (((5 / 80) * *Mwmax) * 0.4));
}

/*@ requires \valid(Mtmin_in);
  @ requires \valid(Mwmin);
  @ requires \valid(Mtmin_out);
  @
  @ behavior UnderEstimate_Motoring:
  @ assumes \true;
  @ ensures *Mtmin_out == *Mtmin_in < 0.85 * *Mwmin ? *Mtmin_in : 0.85 * *Mwmin;
  @*/
void bar(float* Mtmin_in, float* Mwmin, float* Mtmin_out) {
  *Mtmin_out = 0.85 * *Mwmin;
}

int main(void) {
  float f = 1.0, g = 1.0, h;
  foo(&f, &g, &h);
  bar(&f, &g, &h);
  return 0;
}
