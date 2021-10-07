/* run.config*
   OPT: -aorai-automata %{dep:@PTEST_NAME@.ya} -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
   OPT: -aorai-automata %{dep:assigns_det.ya} -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
 LIBS:
 MODULE: name_projects
   OPT: -aorai-automata %{dep:@PTEST_NAME@.ya} -then -print
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
