/* run.config
   COMMENT: integer constant
   COMMENT: waiting for fixing BTS #745 */
void main() {
  /*@ assert 0 == 0; */
  /*@ assert 0 != 1; */
  /*@ assert 0xfffffffffffffff == 0xfffffffffffffff; */

  /* /\*@ assert 0xffffffffffffffffffffffffffffffff == 0xffffffffffffffffffffffffffffffff; *\/ */
}
