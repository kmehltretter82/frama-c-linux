/* run.config_qualif
   DONTRUN:
*/

/*@ axiomatic Ax {
      predicate P(integer i);
      predicate Q(integer i);
      predicate R(integer i);
      predicate S(integer i);
      predicate W(integer i);
  }
*/

int x ;

void function(void){
  int i = 0;
  /*@ loop invariant       IP: P(i) ;
    @ check loop invariant IQ: Q(i);
    @ admit loop invariant IR: R(i);
    @ loop invariant       IS: S(i);
    @ loop assigns i ; */
  while(i < 10) i++ ;

  //@ check W(i);
}
