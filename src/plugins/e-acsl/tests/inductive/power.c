/* run.config
   STDOPT: +"-eva-unroll-recursive-calls 5"
*/

/*@

  inductive power(ℤ x, ℤ y, ℤ p) {
      case zero: \forall ℤ a; power(a, 0, 1);
      case non_zero: \forall ℤ a,b,q; power(a,b-1,q) ==> power(a,b,q*a);
  }

@*/

int main() {
  /*@ assert power(2,3,8); @*/
  /*@ assert !power(2,3,7); @*/
  return 0;
}
