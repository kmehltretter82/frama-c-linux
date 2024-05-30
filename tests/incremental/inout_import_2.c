/* run.config
  DONTRUN: main test is in inout_import_1.c
*/

int b = 0;

void f2()
{
}
int f1()
{
  b = 1; // InOut import on this base fails
  return b;
}

void main()
{
  f1();
  f2();
}
