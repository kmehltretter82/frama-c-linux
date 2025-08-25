/* run.config
   COMMENT: Can be extracted in complete mode, even though it has a complex argument
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

/*@

  inductive P(ℤ i, ℤ x) {
      case one: \forall ℤ n; n ≡ 0 ==> P(n, n+1);
      case two: \forall ℤ n; n ≡ 0 ==> P(n, n+2);
  }

@*/

int main() {
  /*@ assert P(0, 1); @*/
  /*@ assert P(0, 2); @*/
  return 0;
}
