/* run.config
STDOPT: +"-dive-from main::w"
*/

volatile int nondet;

int f(int x, int z)
{
  if (nondet)
    x = z;
  return x;
}

int main(int x, int z)
{
  int w = f(x,z);
  return w + 1;
}
