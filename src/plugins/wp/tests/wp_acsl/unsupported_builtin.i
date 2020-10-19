/* run.config
  MODULE: @PTEST_NAME@.cmxs
*/
/* run.config_qualif
  DONTRUN:
*/
/*@ ensures unimplemented_builtin ; */
void foo(void);

int main(void){
  foo();
  //@ assert \true ;
}
