/* run.config
   OPT: -check -print
 */
/*@ ext_type load: foo ; */
/*@
  axiomatic Pred {
    predicate P(foo f) reads \nothing ;
  }
*/
/*@ lemma X: \forall foo f ; P(f) ; */
