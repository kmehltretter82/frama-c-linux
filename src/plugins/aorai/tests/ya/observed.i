/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

void f(void) {}

void g(void) {}

void h(void) {}

int main() {
  f();
  g();
  h();
}
