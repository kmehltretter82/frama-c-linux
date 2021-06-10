/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -aorai-acceptance -load-module tests/Aorai_test -main f -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

int f(int x) {
  return x;
}
