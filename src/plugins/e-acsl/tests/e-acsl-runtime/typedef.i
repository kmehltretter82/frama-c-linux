/* run.config
   COMMENT: typedef (from a Bernard's bug report)
   COMMENT: no diff
   COMMENT: no diff
*/

typedef unsigned char uint8;

int main(void) {
  uint8 x = 0;
  /*@ assert x == 0; */ ;
  return 0;
}
