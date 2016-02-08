/* run.config
   COMMENT: assert \false
   COMMENT: no diff
   COMMENT: no diff
*/
int main(void) {
  int x = 0;
  if (x) /*@ assert \false; */ ;
  return 0;
}
