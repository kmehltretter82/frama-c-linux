/* run.config
   COMMENT: extracts twice function from twice predicates using different modes
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

/*@

  inductive Q(ℤ x, ℤ y, ℤ z) {
      case zero: ∀ ℤ x; Q(x, 0, 0);
  }

  inductive P(ℤ x,ℤ y) {
      case c: \forall ℤ a,b,c; Q(0,b,0) ==> Q(0,0,c) ==> P(a,b+c);
  }

*/

int main() {
  /*@ assert P(0,0); @*/
  return 0;
}
