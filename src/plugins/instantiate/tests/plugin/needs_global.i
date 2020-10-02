/* run.config
   MODULE: needs_globals.cmxs
   OPT: -instantiate -check -print
*/

int i ; // needed for already_one specifciation
void already_one(void* parameter) ;

void needs_new(void* parameter) ;

void foo(void){
  int *i ;
  already_one(i);
  needs_new(i);
}
