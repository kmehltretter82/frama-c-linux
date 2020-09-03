/* run.config
   CMXS: @PTEST_NAME@
   OPT: @EVA_CONFIG@ -load-module @PTEST_NAME@
*/

int* f() {
  int x;
  return &x;
}

void main(int x) {
  int *p = f();
  *p = 1;
}
