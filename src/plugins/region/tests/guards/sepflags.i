/*@
  region A: a[0..n], \nullable;
  region B: b[0..n], \nullable;
  assigns \nothing;
  */
void f(int *a, int *b, int n);

//@ region a[0..n], b[0..n], \nullable ;
void job(int *a, int *b, int n) { f(a,b,n); }
