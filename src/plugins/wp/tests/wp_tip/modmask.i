/* run.config
   OPT: -wp-par 1 -wp-no-print -wp-prover qed,tip -wp-msg-key script -wp-session @PTEST_SUITE_DIR@/oracle@PTEST_CONFIG@/@PTEST_NAME@.@PTEST_NUMBER@.session
   OPT: -wp-par 1 -wp-no-print -wp-prover qed,tip -wp-msg-key script -wp-session @PTEST_SUITE_DIR@/oracle@PTEST_CONFIG@/@PTEST_NAME@.@PTEST_NUMBER@.session
*/
/* run.config_qualif
   DONTRUN:
*/

/*@
  check lemma and_modulo_us_255:
    \forall unsigned short us ; (us & 0xFF) == us % 0x100 ;
*/

/*@
  check lemma and_modulo_u:
    \forall unsigned us, integer shift;
      0 <= shift < (sizeof(us) *  8) ==> (us & ((1 << shift) - 1)) == us % (1 << shift);
*/
