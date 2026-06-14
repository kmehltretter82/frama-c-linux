/* run.config
 DEPS: @PTEST_DEPS@ abs.mlw
  OPT: -wp-driver %{dep:@PTEST_DIR@/abs.driver} -wp-library @PTEST_DIR@
 */
/* run.config_qualif
 DEPS: @PTEST_DEPS@ abs.mlw
  OPT: -wp-driver %{dep:@PTEST_DIR@/abs.driver} -wp-library @PTEST_DIR@
*/
/*@ axiomatic Absolute { logic integer ABS(integer x) ; } */

/*@ ensures \result == ABS(x) ; */
int abs(int x)
{
  if (x < 0) return -x ;
  return x ;
}
