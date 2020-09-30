/* run.config
   MODULE: @PTEST_NAME@.cmxs
   STDOPT: +"-no-print" +"-kernel-warn-key transient-block=active"
*/

void f(void) { }

int main () {

  int x = 1;
  x = 2;
  f();

}
