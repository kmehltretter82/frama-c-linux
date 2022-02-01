/* run.config
   OPT: -wp-rte -wp-smoke-tests
*/

/* run.config_qualif
   OPT: -wp-rte -wp-smoke-tests
*/

int access(int *ptr){
  if(ptr) *ptr = 42;
  else *ptr ;
	return 0 ;
}
