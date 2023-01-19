

int * addr(int* x)
{
    return x;
}

int main(void)
{
  int *a, *b, c;
  a = addr(&c);
  b = &c;
  return 0;
}
