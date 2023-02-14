// double pointer assignment
//  { *b; *d } are aliased
//  { b; d; *a; *c } are aliased


int main () {

  int **a=0, *b=0, **c=0, *d=0;
  *a = b;
  *c = d;
  b = d;
  return 0;
}
