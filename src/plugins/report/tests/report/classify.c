/* run.config
   PLUGIN: wp rtegen @PLUGIN@
   CMD: @frama-c@ -kernel-warn-key=annot-error=active -report-output classified.@PTEST_NUMBER@.json -wp -wp-msg-key shell @OPTIONS@
   LOG: classified.@PTEST_NUMBER@.json
   OPT: -wp-prover qed -report-unclassified-untried REVIEW -then -report-classify
EXIT: 1
   LOG: classified.@PTEST_NUMBER@.json
   OPT: -wp-prover qed -report-unclassified-warning ERROR -then -report-classify
   LOG: classified.@PTEST_NUMBER@.json
   OPT: -wp-prover qed -report-unclassified-warning ERROR -report-no-status -then -report-classify
   LOG: classified.@PTEST_NUMBER@.json
   OPT: -wp-prover qed  -report-rules %{dep:classify.json} -report-unclassified-warning ERROR -then -report-classify
   LOG: classified.@PTEST_NUMBER@.json
   OPT: -wp-prover qed  -report-rules %{dep:classify.json} -report-unclassified-untried REVIEW -then -report-classify
   LOG: classified.@PTEST_NUMBER@.json
   OPT: -wp-prover none -report-rules %{dep:classify.json} -report-unclassified-untried REVIEW -then -report-classify
*/


int a ;

/*@ requires a >= 0 ;
    ensures a > 0 ;
    assigns a ;
 */
void f(void) {
  //@ assert ignored-annotation;
  a++ ;
}

