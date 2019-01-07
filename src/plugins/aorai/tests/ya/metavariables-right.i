/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -aorai-test 1 -load-module tests/aorai/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

void f(int x) {}
void g(void) {}
void h(int x) {}
void i(void) {}

void main(int t)
{
  if (t) {
    f(42);
  }
  else {
    g();
    goto L;
  }

  int x = 0;
  while (x < 100)
  {
    h(x);
    L: i();
    x++;
  }
}
