/* run.config
   STDOPT: +"-eva-unroll-recursive-calls 5"
*/

/*@

    inductive gcd(ℤ a, ℤ b, ℤ r) {
      case zero: ∀ ℤ x; gcd(x, 0, x);
      case succ:
        ∀ ℤ x, y, z;
          y != 0 ==> gcd(y, x % y, z) ==> gcd(x, y, z);
    }

*/

int main() {
  /*@ assert gcd(42, 24, 6); */
  /*@ assert !gcd(42, 24, 7); */
  return 0;
}
