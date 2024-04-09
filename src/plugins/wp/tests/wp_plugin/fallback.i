/* run.config_qualif
   EXIT: 1
   OPT: -wp-prover=Alt-Ergo:1.2.0
 */

/*@ ensures \result == a * b ; */
int job(int a,int b) { return (a - 1)*b + b ; }
