/* run.config
   COMMENT: sizeof
   EXECNOW: LOG gen_sizeof.c BIN gen_sizeof.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/sizeof.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_sizeof.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_sizeof.out ./tests/e-acsl-runtime/result/gen_sizeof.c -lgmp && ./tests/e-acsl-runtime/result/gen_sizeof.out
   EXECNOW: LOG gen_sizeof2.c BIN gen_sizeof2.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/sizeof.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_sizeof2.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_sizeof2.out ./tests/e-acsl-runtime/result/gen_sizeof2.c -lgmp && ./tests/e-acsl-runtime/result/gen_sizeof2.out
*/

int main(void) {
  int x = 0;
  /*@ assert sizeof(int) == sizeof(x); */ ;
  /*@ assert sizeof("totototototo") == sizeof(char *); */ ;
  return 0;
}
