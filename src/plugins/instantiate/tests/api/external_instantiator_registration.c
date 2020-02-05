/* run.config
   OPT: -load-script tests/api/external_instantiator_registration.ml -instantiate -check -print
*/

void mine(void* parameter) ;

void foo(void){
  int *i ;
  float *f ;

  mine(i);
  mine(f);
}
