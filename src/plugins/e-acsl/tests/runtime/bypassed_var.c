/* run.config
   COMMENT: Variable, which declaration is bypassed by a goto jump
*/

int bypassed_var(int i) {
  int lst [2];
  if (i)
    goto L;

  {
    int *p;
    p = &lst;
    /* assert \valid(p); */

    L:
      p++; /* Important to keep this statement here to make sure
              initialize is ran after store_block */

    if (!i) {
      /*@ assert \valid(p); */
    } else {
      /*@ assert !\valid(p); */
    }
  }
  return i;
}

int main(int argc, char const **argv) {
  bypassed_var(0);
  bypassed_var(1);
  return 0;
}
