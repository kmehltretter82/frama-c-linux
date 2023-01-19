// control structure and arrays
// { a; b; c } are aliased

int main ()
{
  int *a=0, *b=0, *c=0, *d=0, e=0;
  switch (e) {
  case 1:
    *a=e;
    break;
  case 2:
    *b=e;
    break;
  default:
    *c=e;
  }
    
  return 0;
}
