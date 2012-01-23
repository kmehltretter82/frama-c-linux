/* run.config
   COMMENT: typedef (from a Bernard's bug report)
   EXECNOW: LOG gen_typedef.c BIN gen_typedef.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/typedef.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_typedef.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_typedef.out ./tests/e-acsl-runtime/result/gen_typedef.c -lgmp && ./tests/e-acsl-runtime/result/gen_typedef.out
   EXECNOW: LOG gen_typedef2.c BIN gen_typedef2.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/typedef.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_typedef2.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_typedef2.out ./tests/e-acsl-runtime/result/gen_typedef2.c -lgmp && ./tests/e-acsl-runtime/result/gen_typedef2.out
*/

typedef unsigned char uint8;

int main(void) {
  uint8 x = 0;
  /*@ assert x == 0; */ ;
  return 0;
}
