/* run.config
   MODULE: @PTEST_NAME@.cmxs
   OPT: -instantiate -check -print
*/

void mine(void* parameter) ;

void foo(void){
  int *i ;
  float *f ;

  mine(i);
  mine(f);
}
