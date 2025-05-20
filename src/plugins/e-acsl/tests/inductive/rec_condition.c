/* run.config
   STDOPT: +"-eva-unroll-recursive-calls 5"
   COMMENT: shows generation of conditions instead of \let
   COMMENT: P(x,y-1,1) is translated to P(a, b - 1) ≡ 1
*/

/*@

  inductive P(ℤ a, ℤ b, ℤ c) {
    case a: ∀ ℤ x, y; x <= 0 ∨ y <= 0 ⇒ P(x,y,1);
    case b: ∀ ℤ x, y, z; P(x-1,y,z) ==> P(x,y-1,1) ==> P(x,y,x-1);
  }

*/

int main() {
  /*@ assert P(0, 2, 1); */
}
