/* run.config
   COMMENT: sizeof
   EXECNOW: LOG gen_sizeof.c BIN gen_sizeof.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/sizeof.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_sizeof.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_sizeof.out ./tests/e-acsl-runtime/result/gen_sizeof.c
*/

void main() {
  int x = 0;
  /*@ assert sizeof(int) == sizeof(x); */ ;
  /*@ assert sizeof("totototototo") == sizeof(char *); */ ;
}
