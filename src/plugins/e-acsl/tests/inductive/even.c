
/* run.config
   COMMENT:
   STDOPT: +"-eva-unroll-recursive-calls 5"
*/

int zero = 0;

/*@

  inductive even(ℤ x) {
    case zero: \forall ℤ a; even(zero);
    case pos: \forall ℤ a; a >= 2 ==> even(a-2) ==> even(a);
    case neg: \forall ℤ a; a <= -2 ==> even(a+2) ==> even(a);
  }

@*/

int main() {
  /*@ assert even(2); @*/
  /*@ assert !even(3); @*/
  /*@ assert even(-4); @*/
  /*@ assert !even(-3); @*/
  return 0;
}
