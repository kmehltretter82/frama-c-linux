/* run.config
   COMMENT: cast
   EXECNOW: LOG gen_cast.c BIN gen_cast.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/cast.i -e-acsl-project p -e-acsl-include-headers -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_cast.c > /dev/null && gcc -o ./tests/e-acsl-runtime/result/gen_cast.out ./tests/e-acsl-runtime/result/gen_cast.c
*/

void main() {
  long x = 0;
  int y = 0;
  /*@ assert (int)x == y; */ ;
  /*@ assert x == (long)y; */ ;
}
