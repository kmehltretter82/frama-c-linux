main(void) {
  int m = 2;
  int n = 7;;
  K: ;
  n = 875;
  /*@ assert
      \let k = 3;
      \exists integer u; 9 <= u < 21 &&
      \forall integer v; -5 < v <= (u < 15 ? u + 6 : k) ==>
        \at(n + u + v > 0, K); */ ;
  return 0;
}
