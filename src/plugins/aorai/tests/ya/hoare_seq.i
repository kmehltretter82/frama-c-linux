/* run.config*
OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-acceptance -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
*/

void f(void) { }

/*@ behavior bhv:
    assumes c > 0;
    ensures \result == 0;
*/
int main(int c) {
  if (c <= 0) { f (); }
  return 0;
}
