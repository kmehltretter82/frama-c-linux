int K;

/*@
  region *a, *b ;
  assigns *a, *b, K;
  */
void f (int *a, int *b) {
  *a = ++K;
  *b = ++K;
}

void job(int *p, int *q) { f(p,q); }
