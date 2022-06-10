/* run.config
OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
*/

void f(void) {}

void main(void) {
  while (1) f();
}
