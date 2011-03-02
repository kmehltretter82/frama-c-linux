/* run.config
   COMMENT: assert \false */
void main() {
  int x = 0;
  if (x) /*@ assert \false; */ ;
}
