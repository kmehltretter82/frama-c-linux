/* run.config*
OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

int f(int x) { return x; }

int g(int y) { return y; }

int main() { f(1); g(2); }
