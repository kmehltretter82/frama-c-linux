void titi() {
  int c = 0; {
    /*@ ghost int c = 1; */
    c = 2;
  }
  /*@ assert c == 2; */
}
