volatile unsigned int nondet;

/* Intended to let each domain infers some properties. */
void main (int a) {
  //@ taint a;
  int t[100];
  int j = 0;
  for (int i = 0; i < 100; i++) {
    t[j] = nondet;
    j++;
  }
  j = nondet % 100;
  int k = nondet % 100;
  t[k] = 42;
  int r = k - j + 1;
  k = r + j;
  r = t[k-1];
  int x = (a | 8) & 8;
  double d = 11. / 3.;
  double d2 = d * d;
}
