/* run.config
   OPT: -load-script tests/plugin/needs_globals.ml -instantiate -check -print
*/

int i ; // needed for already_one specifciation
void already_one(void* parameter) ;

void needs_new(void* parameter) ;

void foo(void){
  int *i ;
  already_one(i);
  needs_new(i);
}
