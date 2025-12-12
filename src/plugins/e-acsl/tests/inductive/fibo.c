/* run.config
   COMMENT: taken from src/plugins/wp/tests/wp_plugin/tutorial.i
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

/*@

  inductive fibo(ℤ i, ℤ x) {
      case zero: fibo(0, 0);
      case one: fibo(1, 1);
      case other: \forall ℤ n, f1, f2; n>1 ==> fibo(n-1, f1) ==> fibo(n-2, f2) ==> fibo(n, f1+f2);
  }

  // same predicate using two complex arguments in the conclusion
  inductive fibo2(ℤ i,ℤ x) {
      case zero: fibo2(0,0);
      case one: fibo2(1,1);
      case other: \forall ℤ n,f1,f2; n>0 ==> fibo2(n,f1) ==> fibo2(n-1,f2) ==> fibo2(n+1,f1+f2);
  }

@*/

int main() {
  /*@ assert fibo(7, 13); @*/
  /*@ assert fibo2(7, 13); @*/
  /*@ assert !fibo(7, 12); @*/
  /*@ assert !fibo2(7, 12); @*/
  return 0;
}
