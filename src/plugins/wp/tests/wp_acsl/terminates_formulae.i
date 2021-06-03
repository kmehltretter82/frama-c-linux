/* run.config
   OPT: -wp-variant-with-terminates
*/
/* run.config_qualif
   OPT: -wp-variant-with-terminates
*/

/*@
  axiomatic Ax {
    predicate P reads \nothing ;
    predicate Q reads \nothing ;
  }
*/

/*@ terminates P;
    assigns \nothing;
*/
void terminates_P(void);

//@ terminates Q ;
void call(void){
  terminates_P();
}

//@ terminates Q ;
void variant(void){
  /*@ loop assigns i ;
      loop variant i ;
  */
  for(unsigned i = 3; i > 0; --i);
}

//@ terminates Q ;
void no_variant(void){
  //@ loop assigns i ;
  for(unsigned i = 3; i > 0; --i);
}
