/* run.config
   OPT: -load-script tests/api/external_builtin_registration.ml -builtin -check -print
*/

void mine(void* parameter) ;

void foo(void){
  int *i ;
  float *f ;

  mine(i);
  mine(f);
}