/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

void f () {
  int x = 0;
  int y = 0;
  while (x<15) {
    x++;
    while (y<15) { y++; }
    x++;
    y =0;
  }
  x=0;
  y=0;
}
