/* run.config
   OPT: -wp-variant-with-terminates
*/
/* run.config_qualif
   OPT: -wp-variant-with-terminates
*/

int a ;

/*@
  axiomatic Ax {
    predicate P reads a ;
    predicate Q reads \nothing ;
  }
*/

/*@ terminates P;
    assigns \nothing;
*/
void terminates_P(void);

//@ terminates Q ;
void base_call(void){
  terminates_P();
}

//@ terminates P ;
void call_same(void){
  terminates_P();
}

//@ terminates P ;
void call_change(void){
  a = 0 ;
  terminates_P();
}

/*@ terminates *p ;
    assigns \nothing ;
*/
void call_param(int* p);

//@ terminates *p ;
void call_param_same(int *p){
  call_param(p);
}

//@ terminates *p ;
void call_param_change(int *p){
  *p = 0 ;
  call_param(p);
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
