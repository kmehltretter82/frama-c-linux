/* run.config
   COMMENT: testing assert true and false */
void main() {
  int x = 0;
  /*@ assert \true; */
  if (x) /*@ assert \false; */ ;
}
