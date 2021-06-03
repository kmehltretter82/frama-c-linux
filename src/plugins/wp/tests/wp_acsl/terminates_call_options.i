/* run.config
   OPT:
   OPT: -wp-declarations-terminate -wp-definitions-terminate
*/
/* run.config_qualif
   OPT:
   OPT: -wp-declarations-terminate -wp-definitions-terminate
*/

// -wp-declaration-terminates <--- default to FALSE
// -wp-definition-terminates  <--- default to FALSE

//@ assigns \nothing ;
void declaration(void);

//@ assigns \nothing ;
void definition(void){}

//@ terminates \true ;
void call_declaration(void){
  declaration();
}

//@ terminates \true ;
void call_definition(void){
  definition();
}
