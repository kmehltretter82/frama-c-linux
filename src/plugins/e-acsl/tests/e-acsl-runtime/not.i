/* run.config
   COMMENT: predicate [!p] */
void main() {
  int x = 0;
  /*@ assert ! \false; */
  if (x) /*@ assert ! \true; */ ;
}
