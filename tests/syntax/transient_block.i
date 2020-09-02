/* run.config
   CMXS: @PTEST_NAME@
   OPT: -load-module %{dep:@PTEST_NAME@.cmxs} -kernel-warn-key transient-block=active
*/

void f(void) { }

int main () {

  int x = 1;
  x = 2;
  f();

}
