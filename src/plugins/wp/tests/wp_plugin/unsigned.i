/* run.config
   DONTRUN:
*/

/* run.config_qualif
   DEPS: @WP_SESSION@/script/*
   OPT: -wp-prover script @USING_WP_SESSION@
*/

/*@
  lemma U32:
  \forall unsigned int x; (x & ((1 << 32)-1)) == x ;
 */
