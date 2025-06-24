/* run.config
   COMMENT: depend on a foreign predicate in complete mode
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

/*@

  inductive Q(ℤ x, ℤ y, ℤ z) {
      case zero: ∀ ℤ x; Q(x, 0, 0);
  }

  inductive P(ℤ x,ℤ y) {
      case c: \forall ℤ b,c;
      Q(0,0,c) ==>
      P(b,c);
  }

*/

int main() {
  /*@ assert P(0,0); @*/
  /*@ assert !P(1,2); @*/
  return 0;
}
