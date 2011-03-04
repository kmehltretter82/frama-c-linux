/* run.config
   COMMENT: predicate [!p] */
void main() {
  int x = 0;
  /*@ assert ! x; */
  if (x) /*@ assert x; */ ;
}
