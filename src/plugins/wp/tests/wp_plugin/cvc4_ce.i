/* run.config_qualif
   OPT: -wp -wp-counter-examples -wp-prover cvc4 -wp-status
 */

//@ check lemma wrong: \forall integer x; \abs(x) == x;

//@ ensures \result == \abs(x); assigns \nothing;
int wrong(int x) { return x; }
