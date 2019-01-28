/* run.config
   GCC:
   OPT: -eva -out -input -calldeps -eva-show-progress -pdg -journal-disable  -pdg-print -pdg-verbose 2
*/

int G;

int f1 (int * p1, int x1) {
  *p1 += G + x1;
  return *p1;
}

int main (void) {
  int a = 0, b = 0;
  f1(&a, 3);
  f1(&b, 4);
  return a+b;
}
