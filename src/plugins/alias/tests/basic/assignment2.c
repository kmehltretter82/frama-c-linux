// double pointer assignment

int main () {

  int **a, *b, **c, *d;
  *a = b;
  *c = d;
  a = c;
  return 0;
}
