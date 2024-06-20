/* run.config
MODULE: @PTEST_NAME@
OPT: -print
*/

/*@ import foo: A::B; */
/* predicate check1(B::t x) = B::check(x,0); */

/* import foo: A::B \as C; */
/* predicate check2(C::t x) = A::B::check(x,0); */
