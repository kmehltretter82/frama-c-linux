/* run.config
MODULE: @PTEST_NAME@
OPT:
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
