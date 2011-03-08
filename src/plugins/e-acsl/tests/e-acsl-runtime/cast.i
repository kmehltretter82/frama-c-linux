/* run.config
   DONTRUN:
   COMMENT: cast
   COMMENT: waiting for fixing bts #744 */

void main() {
  long x = 0;
  int y = 0;
  /*@ assert (int)x == y; */ ;
  /*@ assert x == (long)y; */ ;
}
