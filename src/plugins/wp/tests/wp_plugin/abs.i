/* run.config
 COMMENT: depends from files mentionned into "abs.driver"
 DEPS: abs.why abs.mlw abs.script Abs.v
   OPT: -wp-driver %{dep:@PTEST_DIR@/abs.driver}
 */
/* run.config_qualif
 COMMENT: depends from files mentionned into "abs.driver"
 DEPS: abs.why abs.mlw abs.script Abs.v
   OPT: -wp -wp-driver %{dep:@PTEST_DIR@/abs.driver} -wp-prover alt-ergo
   OPT: -wp -wp-driver %{dep:@PTEST_DIR@/abs.driver} -wp-prover native:coq -wp-coq-script %{dep:@PTEST_DIR@/abs.script}
   OPT: -wp -wp-driver %{dep:@PTEST_DIR@/abs.driver} -wp-prover native:alt-ergo
*/
/*@ axiomatic Absolute { logic integer ABS(integer x) ; } */

/*@ ensures \result == ABS(x) ; */
int abs(int x)
{
  if (x < 0) return -x ;
  return x ;
}
