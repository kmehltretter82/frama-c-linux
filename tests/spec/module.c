/* run.config
   STDOPT:
   STDOPT: +"-cpp-extra-args='-DILL_TYPED'"
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
    logic X::t inv(X::t x);
    logic X::t opN(X::t x, integer n) = n >= 0 ? X::opN(x,n) : opN(inv(x),-n);
  }
  import Foo \as A;
  import foo::bar \as B;
  lemma AbsOp: \forall Foo::t x, integer n;
    B::opN(x,\abs(n)) == A::opN(x,\abs(n));
 */

#ifdef ILL_TYPED

/*@

  import Foo \as F;
  logic t x = F::e; // ill-formed: t should be F::t
*/

/*@
  import Foo \as F;
  import foo \as f;
  logic F::t x = f::bar::inv(F::e); // OK
  logic F::t y = bar::inv(F::e); // KO
*/

/*@
  module A {
     logic integer a = 0;
     module B {
       logic integer b = a + 1;
     }
  }

import A::B \as b;

logic integer z = b::a; // KO

*/

#endif
