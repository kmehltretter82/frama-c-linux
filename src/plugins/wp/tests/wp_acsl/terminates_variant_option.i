/* run.config
   OPT:
   OPT: -wp-variant-with-terminates
*/
/* run.config_qualif
   OPT:
   OPT: -wp-variant-with-terminates
*/

// -wp-variant-with-terminates <--- default to FALSE


//@ terminates *p >= 0 ;
void fails_positive(int *p){
  /*@ loop invariant \at(*p, Pre) >= 0 ==> 0 <= *p <= \at(*p, Pre) ;
      loop assigns *p ;
      loop variant *p ;
  */
  while(*p)
    --(*p);
}

//@ terminates !keep_going ;
void fails_decreases(int keep_going){
  unsigned i = 100;
  /*@ loop assigns i;
      loop variant i;
  */
  while(i > 0){
    if(! keep_going) i-- ;
  }
}
