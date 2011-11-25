/* run.config
   COMMENT: arithmetic operations
   COMMENT: add the last assertion when fixing BTS #751
   EXECNOW: LOG gen_arith.c BIN gen_arith.out FRAMAC_SHARE=./share @frama-c@ ./tests/e-acsl-runtime/arith.i -e-acsl-project p -then-on p -print -ocode ./tests/e-acsl-runtime/result/gen_arith.c > /dev/null && gcc -pedantic -o ./tests/e-acsl-runtime/result/gen_arith.out ./tests/e-acsl-runtime/result/gen_arith.c -lgmp && ./tests/e-acsl-runtime/result/gen_arith.out
*/

int main(void) {
  int x = -3;
  int y = 2;

  /*@ assert -3 == x; */ ;
  /*@ assert x == -3; */ ;
  /*@ assert 0 != ~0; */ ;

  /*@ assert x+1 == -2; */ ;
  /*@ assert x-1 == -4; */ ;
  /*@ assert x*3 == -9; */ ;
  /*@ assert x/3 == -1; */ ;
  /*@ assert 0xfffffffffff/0xfffffffffff == 1; */ ;
  /*@ assert x % 2 == -1; */ ;
  /*@ assert -3 % -2 == -1; */ ;
  /*@ assert 3 % -2 == 1; */ ;

  /*@ assert x * 2 + (3 + y) - 4 + (x - y) == -10; */ ;

  /*@ assert (0 == 1) == !(0 == 0); */ ;
  /*@ assert (0 <= -1) == (0 > 0); */ ;
  /*@ assert (0 >= -1) == (0 <= 0); */ ;
  /*@ assert (0 != 1) == !(0 != 0); */ ;

  /*@ assert 0 == !1; */ ;

  return 0;
}
