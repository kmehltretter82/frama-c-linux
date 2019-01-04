/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -aorai-test 1 -load-module tests/aorai/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

void f(int x) {}
void g(void) {}
void h(void) {}

void main(void)
{
  int x = 0;
  while (x < 100)
  {
    if (x % 2)
      f(x);
    else
      g();
    h();
    x++;
  }
}

