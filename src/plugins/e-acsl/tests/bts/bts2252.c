/* run.config
   COMMENT: bts #2252, failures due to typing of offsets
*/

int main(void) {
  int i = -1;
  int t[10];
  /*@ assert ! \valid_read(t+i); */
  return 0;
}
