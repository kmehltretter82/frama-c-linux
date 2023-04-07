// summary of addr is empty

int * addr(int* x)
{
    return x;
}

int main(void)
{
  int* x = 0;
  int* y = addr(x);
  return 0;
}
