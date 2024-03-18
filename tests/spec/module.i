/* run.config
   EXIT: 1
   OPT:
 */

/*@
  logic integer foo(integer x) = 2*x;
  import int::Int \as Z;
  logic integer foo(integer x) = 2*x;
  module foo::Bar {
    logic integer next(integer x) = Z::add::(+)(x,1);
  }
 */
