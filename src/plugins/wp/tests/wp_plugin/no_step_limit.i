/* run.config
  DONTRUN:
*/
/* run.config_qualif
  CMD: WHY3CONFIG=@PTEST_DIR@/@PTEST_NAME@.conf @frama-c@
  OPT: -wp -wp-prover no-steps -wp-steps 10 -wp-msg-key shell
*/
/*@
  lemma truc: \false ;
*/
