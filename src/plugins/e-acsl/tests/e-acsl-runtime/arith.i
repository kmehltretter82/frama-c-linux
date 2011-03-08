/* run.config
   COMMENT: arithmetic operations */

void main() {
  int x = -3;
  int y = 2;

  /*@ assert -3 == x; */ ;
  /*@ assert x == -3; */ ;
  /*@ assert 0 != ~0; */ ;

  /*@ assert x+1 == -2; */ ;
  /*@ assert x-1 == -4; */ ;
  /*@ assert x*3 == -9; */ ;
  /*@ assert x/3 == -1; */ ;
  /*@ assert x % 2 == -1; */ ;

  /*@ assert x * 2 + (3 + y) - 4 + (x - y) == -10; */ ;

  //  /*@ assert (0 == 1) == !(0 == 0); */ ;

  //  /*@ assert 0 == !1; */ ;
  /* subtyping relation: 0 should be promoted to boolean below
     How to handle this? */
}
