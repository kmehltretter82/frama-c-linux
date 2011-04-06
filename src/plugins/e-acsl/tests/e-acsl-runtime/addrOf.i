/* run.config
   COMMENT: addrOf
   EXECNOW: LOG gen_addrOf.c BIN gen_addrOf.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/addrOf.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_addrOf.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_addrOf.out ./tests/e-acsl-runtime/result/gen_addrOf.c
*/
void main() {
  int x = 0;
  /*@ assert &x == &x; */ ;
}
