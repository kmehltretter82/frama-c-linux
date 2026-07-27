/*@
  region A: a[0..n] ;
  region B: b[0..n], \nullable ;
  region R: c[0..n], \allocated ;
  region R: d[0..n], \nullable, \allocated ;
  assigns \nothing;
  */
void f(int *a, int *b, int *c, int *d, int n);

//@ region a[0..n], b[0..n], c[..], d[..] ;
void job(int *a, int *b, int *c, int *d, int n) { f(a,b,c,d,n); }
