/* run.config
   DONTRUN:
*/
/* run.config_qualif
   CMD: chmod a-x %{dep:../../inexistant-prover} && @frama-c@ @WP_OPTIONS@ @PTEST_OPTIONS@
   OPT: -wp
   OPT: -wp -wp-prover "alt-ergo,native:coq" -wp-alt-ergo %{dep:../../inexistant-prover} -wp-coqc %{dep:../../inexistant-prover}
   OPT: -wp -wp-prover "alt-ergo" -wp-alt-ergo %{dep:../../inexistant-prover}
   OPT: -wp -wp-prover "native:coq" -wp-coqc %{dep:../../inexistant-prover}
*/
 
/*@
  axiomatic A {
  lemma ok_because_inconsistent: \forall integer x;  x > 0 ==> x < 0 ==> x == 0 ;
  }
*/

/*@
  axiomatic B {
  lemma ok_because_consistent: \forall integer x;  x > 0 ==> x*x > 0 ;
  }
*/
