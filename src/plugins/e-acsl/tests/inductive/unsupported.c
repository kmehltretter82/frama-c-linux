/* run.config
   COMMENT: no valid mode; for testing user feedback
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

// impossible without function inversion
/*@
  inductive P1(ℤ x) {
      case c: \forall ℤ a; P1(1/a);
  }
@*/

// two complex conclusion arguments
/*@
  inductive P2(ℤ i,ℤ x) {
      case zero: P2(0,0);
      case one: P2(1,1);
      case other: \forall ℤ n,f1,f2; n>1 ==> P2(n-1,f1) ==> P2(n-2,f2) ==> P2(n+1,f1+f2);
  }
@*/

// impossible without \let inversion
/*@
  inductive P3(ℤ a, ℤ b) {
      case c: \forall ℤ x,y; \let v = x; P3(v, y);
  }
@*/

// c does not occur in the conclusion (and is not bound by a recursive hypothesis)
/*@
    inductive eq(ℤ x, ℤ y) {
        case c: \forall ℤ a, b, c; a == c ==> b == c ==> eq(a, b);
    }
*/

// adapted from tests/spec/max.c. Problem here: p[l] has to be substituted by
// max. The current algorithm tries to solve p[l] = max for p and for l.
// Instead we should just substitute the entire tlval.
/*@
  inductive is_max(int *ptr, integer length, integer max) {

    case max_eq:
      \forall int *p;
        is_max(p, 1, p[0]);

    case max_gt:
      \forall int *p, l, m;
        is_max(p, l-1, m) ==> p[l-1] >= m ==> is_max(p, l, p[l-1]);

    case max_lt:
      \forall int *p, l, m;
        is_max(p, l-1, m) ==> p[l-1] <= m ==> is_max(p, l, m);

  }
*/

int t[4] = {1, 3, 2, 4};

int main() {
  /*@ assert P1(1); @*/
  /*@ assert P2(7,13); @*/
  /*@ assert P3(2,3); @*/
  /*@ assert eq(2, 2); */
  /*@ assert !eq(2, 3); */

  int *ptr = (int *)&t;
  /*@ assert is_max(ptr, 1, 1); */

  return 0;
}
