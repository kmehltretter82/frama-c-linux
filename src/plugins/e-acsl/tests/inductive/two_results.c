/* run.config
   COMMENT: Shows that the current implementation is unsound in case of overlapping cases.
   COMMENT: zero1 is shadowed by zero0 in extracted logic function
   STDOPT: +"-eva-unroll-recursive-calls 9"
*/

/*@

  inductive P(ℤ x, ℤ y) {
      case zero0: P(0, 0);
      case zero1: P(0, 1);
      case other: \forall ℤ x, z; x>0 ==> P(x-1, z) ==> P(x, x+z);
  }

@*/

int main() {
  /*@ assert P(0, 0); */
  /*@ assert P(1, 1); */
  /*@ assert P(0, 1); */ // unsound result: FAIL
  return 0;
}
