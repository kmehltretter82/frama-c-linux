/* run.config
   COMMENT: addrOf
   EXECNOW: LOG gen_addrOf.c BIN gen_addrOf.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/addrOf.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_addrOf.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_addrOf.out ./tests/e-acsl-runtime/result/gen_addrOf.c && ./tests/e-acsl-runtime/result/gen_addrOf.out
*/

int main(void) {
  int x = 0;
  /*@ assert &x == &x; */ ;
  return 0;
}
