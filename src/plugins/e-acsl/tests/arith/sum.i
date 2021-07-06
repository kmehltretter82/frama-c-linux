/* run.config
   COMMENT: sum operations
*/

int main(void) {
  unsigned long x = 4294967295UL;
  int y = 10;

  /*@ assert \sum(2,10,\lambda integer k; 2*k) == 108; */; 

  /*@ assert \sum(2,35,\lambda integer k; 18446744073709551615) != 0; */; 

  /*@ assert \sum(10,2,\lambda integer k; k) == 0; */; 

  /*@ assert \sum(x*x,2,\lambda integer k; k) == 0; */; 

  /*@ assert \sum(18446744073709551610,18446744073709551615,\lambda integer k; 1) == 6; */;
  

  return 0;
}
