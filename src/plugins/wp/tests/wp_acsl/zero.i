/* run.config
  OPT:
  OPT:  -wp-model real
*/

/* run.config_qualif
  OPT:
  OPT: -wp-model real
*/

//@ predicate Foo(double y) = y == 0.0;

void foo(double x) {
  //@ assert Foo((double) (0.0 + 0.0 * x));
}
