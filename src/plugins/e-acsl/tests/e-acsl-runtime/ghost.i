/* run.config
   COMMENT: ghost code
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\"" +"-val-builtin __malloc:Frama_C_alloc_size -val-builtin __free:Frama_C_free"
   COMMENT: no diff
   COMMENT: no diff
*/

/*@ ghost int G = 0; */
/*@ ghost int *P; */

// /*@ ghost int foo(int *x) { return *x + 1; } */

int main(void) {
  /*@ ghost P = &G; */ ;
  /*@ ghost int *q = P; */
  /*@ ghost (*P)++; */
  /*@ assert *q == G; */
  //  /*@ ghost G = foo(&G); */
  //  /*@ assert G == 2; */
}
