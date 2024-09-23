/* run.config
MODULE: @PTEST_NAME@
OPT: -print
OPT: -print -kernel-msg-key printer:imported-modules
*/

/*@ import foo: A::B; */
/*@ predicate check1(B::t x) = B::check(x,0); */
/*@ predicate check2(A::B::t x) = A::B::check(x,0); */

/*@ import foo: A::B \as C; */
/*@ predicate check3(C::t x) = C::check(x,0); */
/*@ predicate check4(C::t x) = A::B::check(x,0); */
