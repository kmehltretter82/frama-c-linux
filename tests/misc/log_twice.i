/* run.config
   CMXS: @PTEST_NAME@
   OPT: @EVA_CONFIG@ -load-module %{dep:@PTEST_NAME@.cmxs}
*/

int* f() {
  int x;
  return &x;
}

void main(int x) {
  int *p = f();
  *p = 1;
}
