
void f (int n) {
  //@ loop variant n - i;
  for (int i = 0; i < n; i++) {
    /*@ assert \at(i,LoopEntry) == 0; */
    int j = 0;
    //@ loop variant i - j;
    while (j++ < i) {
      /*@ assert \at(j,LoopEntry) == 0; */
      /*@ assert \at(j,LoopCurrent) + 1 == j; */
    }
  }
}
