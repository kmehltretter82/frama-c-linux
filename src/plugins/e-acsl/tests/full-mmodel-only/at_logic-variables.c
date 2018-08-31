/* run.config
   COMMENT: \at with logic variables
   COMMENT: For now, only works with full memory model,
            and without --gmp-only
*/

/*@ ensures \forall integer n; 1 < n <= 3 ==> \old(t[n] == 12); */
void f(int *t) {}

int main(void) {
  int n;
  n = 7;
  L: ;
  n = 9;
  K: ;
  n = 666;

  // Predicates:
  /*@ assert \let i = 3; \at(n + i == 10, L); */ ;
  /*@ assert \exists integer j; 2 <= j < 5 && \at(n + j == 11, L); */ ;
  /*@ assert
      \let k = -7;
      \exists integer u; 9 <= u < 21 &&
      \forall integer v; -5 < v <= 6 ==>
        \at((u > 0 ? n + k : u + v) > 0, K); */ ;

  // Terms:
  /*@ assert \let i = 3; \at(n + i, L) == 10; */ ;
  unsigned int m = 3;
  G: ;
  m = -3;
  /*@ assert \exists integer k; -9 < k < 0 && \at(m + k, G) == 0; */ ;
  /*@ assert
      \exists integer u; 9 <= u < 21 &&
      \forall integer v; -5 < v <= (u < 15 ? u + 6 : 3) ==>
        \at(n +  u + n > 0, K); */ ;

  // Function contracts:
  int t[5] = {9, 12, 12, 12, -4};
  f(t);

  // Not yets:
  /*@ assert
        \exists integer j; 2 <= j < 10000000000000000 // too big => not_yet
        && \at(n + j == 11, L); */ ;
  /*@ assert \let i = n; // TODO: lv defined with C var => not_yet
        \at(n + i == 10, L); */ ;

  return 0;
}