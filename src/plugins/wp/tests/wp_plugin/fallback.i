/* run.config_qualif
   DEPS: @PTEST_DEPS@ @WP_SESSION@/script/job_ensures.json
   OPT: -wp-prover script @USING_WP_SESSION@
 */

/*@ ensures \result <= 1000 ; */
int job(int a,int b){
  return (a - 1) * b + b ;
}
