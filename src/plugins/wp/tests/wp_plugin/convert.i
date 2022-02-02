/* run.config
   OPT:
*/

/* run.config_qualif
   OPT:
   OPT: -wp-prover native:alt-ergo -wp-report=%{dep:@PTEST_SUITE_DIR@/../native.report}
*/

// --------------------------------------------------------------------------
// --- Conversions
// --------------------------------------------------------------------------

//@ lemma floor: \forall real x; \floor(x) <= x < \floor(x)+1 ;
//@ lemma ceil:  \forall real x; \ceil(x)-1 < x <= \ceil(x) ;
