/* run.config*
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
   OPT: -aorai-automata %{dep:@PTEST_DIR@/assigns_det.ya} -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
 MODULE: name_projects
 LIBS:
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -then -print
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
