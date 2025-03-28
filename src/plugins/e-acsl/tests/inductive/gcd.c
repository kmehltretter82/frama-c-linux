/* run.config
   STDOPT: +"-eva-unroll-recursive-calls 5"
*/

/*@

    inductive gcd(ℤ n, ℤ m, ℤ r) {
      case gcd_zero:
        \forall ℤ x;
          gcd(x, 0, x);

      case gcd_S:
        \forall ℤ x, y, z;
          y != 0 ==> gcd(y, x % y, z) ==> gcd(x, y, z);
    }

*/

int main() {
  /*@ assert gcd(42, 24, 6); */
  /*@ assert !gcd(42, 24, 7); */
  return 0;
}
