/* run.config
   COMMENT: cast
   STDOPT: #"-no-warn-signed-downcast" #"-no-warn-unsigned-downcast"
   COMMENT: no diff
   EXECNOW: LOG gen_cast2.c BIN gen_cast2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/gmp/cast.i -e-acsl-gmp-only -no-warn-signed-downcast -no-warn-unsigned-downcast -e-acsl -then-on e-acsl -print -ocode ./tests/gmp/result/gen_cast2.c > /dev/null && ./gcc_runtime.sh cast2
*/

int main(void) {
  long x = 0;
  int y = 0;

  /*@ assert (int)x == y; */ ;
  /*@ assert x == (long)y; */ ;

  /*@ assert y == (int)0; */ ; // cast from integer to int
  /*@ assert (unsigned int) y == (unsigned int)0; */ ; /* cast from integer
  						          to unsigned int */

  /*@ assert y != (int)0xfffffffffffffff; */ ; // cast from integer to int
  /*@ assert (unsigned int) y != (unsigned int)0xfffffffffffffff; */ ; 
  /* cast from integer to unsigned int */

  return 0;
}
