/* run.config
   OPT: -eva -eva-show-progress -scf -eva-show-progress -journal-disable
*/

void f(int *x) { (*x)++; }

int main () {
  int Y = 42;
  f(&Y);
  return Y;
}
