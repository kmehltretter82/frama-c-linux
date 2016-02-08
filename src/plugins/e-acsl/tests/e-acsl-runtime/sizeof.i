/* run.config
   COMMENT: sizeof
   COMMENT: no diff
   COMMENT: no diff
*/

int main(void) {
  int x = 0;
  x++; /* prevent GCC's warning */
  /*@ assert sizeof(int) == sizeof(x); */ ;
  return 0;
}
