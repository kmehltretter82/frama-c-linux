/* run.config
   OPT: -wp-model Caveat
*/
/* run.config_qualif
   OPT: -wp-model Caveat
*/

int x ;
int *g ;

/*@ assigns *g, *p, x ;
    wp_nullable_pointers p ;
*/
void nullable_coherence(int* p){
  if(p == (void*)0){
    //@ check must_fail: \false ;
    return;
  }
  //@ check \valid(p);
  *p = 42;
  *g = 24;
  x = 1;
}

/*@ assigns *p, *q, *r, *s, *t ;
    wp_nullable_pointers p, q, r ;
*/
void nullable_in_context(int* p, int* q, int* r, int* s, int* t){
  *p = 42;
  *q = 42;
  *r = 42;
  *s = *t = 0;
}
