

int* my_malloc(int size) {
  int* res= malloc(size);
  return res;
}




int main(void)
{
  int *a, *b;
  a=my_malloc(2);
  b=my_malloc(3);
  return 0;
}
