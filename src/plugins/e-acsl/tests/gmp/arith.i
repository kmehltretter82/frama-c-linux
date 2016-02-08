/* run.config
   COMMENT: arithmetic operations
   COMMENT: add the last assertion when fixing BTS #751
   COMMENT: no diff
   COMMENT: no diff
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
  /*@ assert 0xffffffffffffffffffffff/0xffffffffffffffffffffff == 1; */ ;
  /*@ assert x % 2 == -1; */ ;
  /*@ assert -3 % -2 == -1; */ ;
  /*@ assert 3 % -2 == 1; */ ;

  /*@ assert x * 2 + (3 + y) - 4 + (x - y) == -10; */ ;

  /*@ assert (0 == 1) == !(0 == 0); */ ;
  /*@ assert (0 <= -1) == (0 > 0); */ ;
  /*@ assert (0 >= -1) == (0 <= 0); */ ;
  /*@ assert (0 != 1) == !(0 != 0); */ ;

  /*@ assert 0 == !1; */ ;
  /*@ assert 4 / y == 2; */ /* non trivial division */

  return 0;
}
