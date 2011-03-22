/* run.config
   COMMENT: assert \true
   EXECNOW: LOG gen_true.c BIN gen_true.out FRAMAC_SHARE=./share frama-c -load-module E_ACSL ./tests/e-acsl-runtime/true.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_true.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_true.out ./tests/e-acsl-runtime/result/gen_true.c
*/
void main() {
  int x = 0;
  /*@ assert \true; */
}
