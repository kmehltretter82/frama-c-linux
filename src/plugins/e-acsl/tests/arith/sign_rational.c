/* run.config
   COMMENT: a logic function defined over rationals
*/

/*@
    logic integer signum(ℝ x) =
      x > 0. ? 1 : x < 0. ? -1 : 0;
*/

int main() {
  /*@ assert signum(3.0) > 0; */
  /*@ assert signum(0.0-3.0) < 0; */
  /*@ assert signum(0.0) ≡ 0; */
  return 0;
}
