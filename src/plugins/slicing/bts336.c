/* run.config
 OPT: -calldeps -slice-return main -slice-print
*/

int T[10];

int f (int i) {
  T[i] ++;
  return T[i];
}

int main (void) {
  int x1 = f(1);
  int x2 = f(2);
  return x2;
}
