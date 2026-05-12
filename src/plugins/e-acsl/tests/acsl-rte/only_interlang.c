/* run.config
 * COMMENT: Check that the RTE guards are generated at the right place with
 *          interlang forced.
 * STDOPT: #"-e-acsl-interlang-force -e-acsl-msg-key interlang:not_covered"
*/

int main() {
  int x = 1;
  /*@ assert 12 / x > 0; */
  /*@ assert 12 / (x + 1) == 6; */

  return 0;
}
