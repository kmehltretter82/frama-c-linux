/* run.config
MODULE: @PTEST_NAME@.cmxs
OPT: #"-no-print"
*/

/*@
  requires -3 <= c <= 4;
  ensures \result >= c;
*/
int f(int c) {
  if (c>0) return c; 
  //@ assert c <= 0;
  return 0; 
}
