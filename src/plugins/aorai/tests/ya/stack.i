/* run.config*
   OPT: -aorai-automata tests/aorai/stack.ya -aorai-test 1 -load-module tests/aorai/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/


int g = 0;

void push(void)
{
  g++;
}

void pop(void)
{
  //@ assert g > 0;
  g--;
}

void main(void)
{
  push();
  pop();
  push();
  push();
  pop();
  push();
  push();
  pop();
  pop();
  pop();
}
