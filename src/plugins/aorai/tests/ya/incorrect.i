/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

int f(void);

int main(void) {
  return f();
}
