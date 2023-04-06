int main()
{
  int* a;
  a = (int*)(& a);
  return *a;
}
