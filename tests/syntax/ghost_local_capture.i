void titi() {
  int c = 0; {
    L0: ;
    /*@ ghost int c = 1; */
    L1: ;
    c = 2;
    /*@ assert c == 1; */
    /*@ assert \at(c,L0) == 0; */
    /*@ assert \at(c,L1) == 1; */
  }
  /*@ assert c == 2; */
}

/*@ ghost int x; */
/*@ ghost void f() { x++; } */
