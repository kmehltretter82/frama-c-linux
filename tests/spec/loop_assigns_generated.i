/* run.config*
MODULE: @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT:
*/

void f() {
  int i = 0;
  /*@ loop assigns i; */
  while (i< 10) { i++; }

  while (i>0) { i--; }
}
