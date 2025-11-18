/* run.config
   COMMENT: foreign incomplete predicate
   COMMENT: binding a variable that will be substituted
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

/*@

  inductive fibo(ℤ i, ℤ x) {
      case zero: fibo(0, 0);
      case one: fibo(1, 1);
      case other: \forall ℤ n, f1, f2; n>1 ==> fibo(n-1, f1) ==> fibo(n-2, f2) ==> fibo(n, f1+f2);
  }

  inductive P(ℤ x, ℤ y) {
      case c: \forall ℤ a; a >= 0 ==> fibo(0,a) ==> P(a,a+a);
  }

  inductive Q(ℤ x, ℤ y) {
      case c: \forall ℤ a; fibo(0,a) ==> Q(a,a+a);
  }

*/

int main() {
  //@ assert P(0,0);
  //@ assert Q(0,0);
  return 0;
}
