/* run.config
  EXIT: 1
  STDOPT:
*/

int g(int x){
  return x + 42;
}

int f(int x) {
  //@ \kernel::calls g;
  return g(x);
}
