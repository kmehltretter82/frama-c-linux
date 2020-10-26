/* run.config
MODULE: @PTEST_NAME@
STDOPT: +"-no-print"
*/

int x;

void f() { x++; }

/*@ axiomatic Ax {
  @   predicate Q (integer v);
  @   }
  @*/

//@ requires Q: \let v = Q(255); !(!v||v) ;
void g (void);

