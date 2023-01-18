void *f1(int *x, int* y)
{
  int *tmp = x;

  while (1) {
    x=y;
    y=tmp;
    break;
  }
  return (void *) 0;
}

int main(void)
{
  int *a, *b, *c, *d;
  f1(a,b);
  f1(c,d);
  return 0;
}
