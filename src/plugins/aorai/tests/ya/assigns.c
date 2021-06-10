/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
   OPT: -aorai-automata @PTEST_DIR@/assigns_det.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
 MODULE: name_projects
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -then -print
*/

int X;

void f(void) { X++; }

/*@ assigns X;
  behavior foo:
  assigns X;
*/
int main () {
  //@ assigns X;
  X++;
  //@ assigns X;
  f();
  return X;
}
