/* run.config
   OPT: -print @PTEST_DIR@/third.c @PTEST_DIR@/second.c
*/
/*@ behavior b:
  requires \valid(first);
  ensures \result == 0;*/
int bar(int *first);

void main (int * c) {
  bar(c);
}
