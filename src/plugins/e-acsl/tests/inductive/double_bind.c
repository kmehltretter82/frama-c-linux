/* run.config
   STDOPT: +"-eva-unroll-recursive-calls 5"
   COMMENT: here z is bound twice.
   COMMENT: This should lead to a \let bind and then a condition
*/

/*@

  inductive P(ℤ a, ℤ b, ℤ c) {
    case a: ∀ ℤ x, y; x <= 0 ∨ y <= 0 ⇒ P(x,y,1);
    case b: ∀ ℤ x, y, z; P(0,y,z) ==> P(x,0,z) ==> P(x,y,x-1);
  }

*/

int main() {
  /*@ assert P(2, 3, 1); */
}
