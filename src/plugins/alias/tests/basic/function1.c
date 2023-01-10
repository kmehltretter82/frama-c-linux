
void swap(int *x, int* y) {
  int*z;
  z=x;
  x=y;
  y=z;
}




int main(void)
{
  int *a, *b, *c, *d;
  swap(a,b);
  swap(c,d);
  return 0;
}
