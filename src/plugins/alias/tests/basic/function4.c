#include <stdio.h>

int * addr(int* x)
{
    return x;
}

int main(void)
{
  int *a, *b, c;
  a = addr(&c);
  b = &c;
  c=4;
  *a=5;
  printf("*b=%d\n",*b);
  return 0;
}
