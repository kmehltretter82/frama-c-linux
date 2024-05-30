/* run.config
   DONTRUN: main test is in modif_2.c
*/

void f2()
{
}
void f1() // Body changed, no cache reload
{
  int a;
}

void main() // Callees changed, no cache reload
{
  f1();
  f2();
}