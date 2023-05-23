// address assignment
// {a, c} are aliased

int main () {

  int *a=0, b=0, *c=0;
  a = &b;
  c = &b;
  return 0;
}
