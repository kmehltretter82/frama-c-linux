// conditional cfg

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
