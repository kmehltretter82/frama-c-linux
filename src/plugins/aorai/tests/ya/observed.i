/* run.config*
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
*/

void f(void) {}

void g(void) {
  for (int i = 0; i < 1; i++) ;
}

void h(void) {
  g();
  g();
}

int main() {
  f();
  g();
  h();
}
