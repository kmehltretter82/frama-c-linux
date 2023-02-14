// conditional cfg
//  {d; *c; } are aliased
//  {a; b; } are aliased
//  {c; *a; *b; } are aliased


int main () {

  int ***a, ***b, **c, *d, e;
  b = &c;
  c = &d;
  d = &e;
  if (a) {
    a = b;
  }
  else {
    a = &c;
  }
  return 0;
}
