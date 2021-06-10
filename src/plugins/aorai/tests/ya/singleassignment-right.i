/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

void main(int *x, int *y)
{
  int t = *x;
  *x = *y;
  *y = t;
}
