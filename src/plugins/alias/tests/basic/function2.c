// malloc
// no alias

int* my_malloc(int size) {
  int* res= malloc(size);
  return res;
}

int main(void)
{
  int *a=0, *b=0;
  a=my_malloc(2);
  b=my_malloc(3);
  return 0;
}
