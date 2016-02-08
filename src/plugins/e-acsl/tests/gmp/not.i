/* run.config
   COMMENT: predicate [!p]
   COMMENT: no diff
   COMMENT: no diff
*/
int main(void) {
  int x = 0;
  /*@ assert ! x; */
  if (x) /*@ assert x; */ ;
  return 0;
}
