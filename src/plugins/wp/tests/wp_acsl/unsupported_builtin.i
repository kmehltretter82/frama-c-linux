/* run.config
  OPT: -load-module @PTEST_DIR@/@PTEST_NAME@.ml
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