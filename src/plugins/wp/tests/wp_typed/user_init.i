/*@ requires \valid(a+(0..n-1)) ;
  @ requires n >= 0 ;
  @ ensures \forall int k ; 0 <= k < n ==> a[k] == v ;
  @ assigns a[0..n-1] ;
*/
void init( int * a , int n , int v )
{
  /*@ loop invariant Range: 0 <= i <= n ;
    @ loop invariant Partial: \forall int k ; 0 <= k < i ==> a[k] == v ;
    @ loop assigns i,a[0..n-1] ;
  */
  for (int i = 0 ; i < n ; i++) a[i] = v ;
}
//-------------------------
int t1[10];
/*@ ensures \forall integer k; 0 <= k < 10 ==> t1[k] == v ;
  @ exits \false;
  @ assigns t1[0..9] ;
*/
void init_t1(int v) {
  unsigned i;
  /*@ loop invariant Range: 0 <= i <= 10 ;
    @ loop invariant Partial: \forall integer k ; 0 <= k < i ==> t1[k] ≡ v ;
    @ loop assigns i,t1[0..9] ;
  */
  for (i = 0 ; i < 10 ; i++) t1[i] = v ;
}
//-------------------------
int t2[10][20];
/*@ ensures \forall integer k, l; 0 <= k < 10 && 0 <= l < 20  ==> t2[k][l] == v;
  @ exits \false;
  @ assigns t2[0..9][0..19];
  */
void init_t2(int v) {

  unsigned i,j;
  /*@ loop assigns i, j, t2[0..9][0..19];
    @ loop invariant Range_i: 0 <= i <= 10 ;
    @ loop invariant Partial_i: \forall integer k,l; 0 <= k < i && 0 <= l < 20 ==> t2[k][l] == v;
   */
  for(i = 0; i <= 9; i++) {
    /*@ loop assigns j, t2[0..9][0..19];
      @ loop invariant Range_j: 0 <= j <= 20 ;
      @ loop invariant Partial_j: \forall integer l; 0 <= l < j ==> t2[i][l] == v;
      @ loop invariant Previous_i: \forall integer k,l; 0 <= k < i && 0 <= l < 20 ==> t2[k][l] == \at(t2[k][l], LoopEntry);
    */
    for(j = 0; j <= 19; j++) {
      t2[i][j] = v;
    }
    //@ assert j: j==20;
    ;
  }
  //@ assert i: i==10;
  ;
}
//-------------------------
/*@ ensures \forall integer k, l; 0 <= k < 10 && 0 <= l < 20  ==> t2[k][l] == v;
  @ assigns t2[0..9][0..19];
  @ exits \false;
  */
void init_t2_bis(int v) {

  unsigned i;
  /*@ loop assigns i, t2[0..9][0..19];
    @ loop invariant Range_i: 0 <= i <= 10 ;
    @ loop invariant Partial_i: \forall integer k,l; 0 <= k < i && 0 <= l < 20 ==> t2[k][l] == v;
   */
  for(i = 0; i <= 9; i++) {
    init(&t2[i][0], 20, v);
  }
  //@ assert i: i==10;
  ;
}
