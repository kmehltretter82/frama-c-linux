/* run.config
MODULE: @PTEST_NAME@
OPT:
*/

int x;

int f() {
  static int x = 0;
  x++;
  return x;
}

int g() {
  int x = 0;
  x++;
  return x;
}

int main () {
  x++;
  return x;
}
