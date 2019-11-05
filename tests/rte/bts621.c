/* run.config
   OPT: -print -then -no-print -rte -warn-signed-overflow -then -print
*/
/*@ ghost
  /@ assigns *p; @/
  float g(float \ghost* p) ; 
*/

void f(void) /*@ ghost (float a) */ { /*@ ghost float x = g(&a); */ }

