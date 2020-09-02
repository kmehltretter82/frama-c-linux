/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

int x;

void f() { x++; }

/*@ axiomatic Ax {
  @   predicate Q (integer v);
  @   }
  @*/

//@ requires Q: \let v = Q(255); !(!v||v) ;
void g (void);

