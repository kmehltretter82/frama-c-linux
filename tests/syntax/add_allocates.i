/* run.config
   CMXS: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} -print
*/


int* x;

void f(void);

//@ allocates x;
void g(void);

//@ behavior b: requires \false; allocates x;
void main(int c) {
  f();
  while (c) {
    //@ loop allocates x;
    while (1) {
      while (!c);
    }
    //@ for b: loop allocates x;
    while (1) {
    }
  }
}
