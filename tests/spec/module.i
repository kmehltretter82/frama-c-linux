/* run.config
   STDOPT:
 */

/*@
  module Foo {
    type t;
    logic t e;
    logic t op(t x, t y);
    logic t opN(t x, integer n) = n >= 0 ? op(x, opN(x,n-1)) : e;
  }
  module foo::bar {
    import Foo \as X;
    logic t inv(X::t x);
    logic t opN(t x, integer n) = n >= 0 ? X::opN(x,n) : opN(inv(x),-n);
  }
  import Foo \as A;
  import foo::bar \as B;
  lemma AbsOp: \forall Foo::t x, integer n;
    B::opN(x,\abs(n)) == A::opN(x,\abs(n));
 */
