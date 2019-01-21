/* run.config
   OPT: -load-script @PTEST_DIR@/@PTEST_NAME@ -eva-show-progress
*/

int* f() {
  int x;
  return &x;
}

void main(int x) {
  int *p = f();
  *p = 1;
}
