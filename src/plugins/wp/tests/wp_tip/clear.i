/* run.config
   OPT: -wp-par 1 -wp-no-print -wp-prover qed,tip -wp-msg-key script -wp-session @PTEST_DIR@/oracle/@PTEST_NAME@.session
*/
/* run.config_qualif
   DONT_RUN:
*/

/*@ axiomatic X {
      predicate P ;
      predicate Q ;
      predicate R ;
      predicate S(integer i) ;
    }
*/

int a = 42, b;

/*@ requires P;
  @ requires Q;
  @ requires R;
  @ ensures S(a+b); */
void clear(void) {
  if (a < b) {
    a++;
  } else {
    b--;
  }
}
