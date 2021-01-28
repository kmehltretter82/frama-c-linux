/* run.config
<<<<<<< HEAD
   CMD: @frama-c@ -wp-msg-key cluster,shell,print-generated -wp-prover why3 @OPTIONS@ -wp-warn-key "pedantic-assigns=inactive"
||||||| ac7807782d
   CMD: @frama-c@ -wp-share ./share -wp-msg-key cluster,shell,print-generated -wp-prover why3
=======
   CMD: @frama-c@ -wp-share ./share -wp-msg-key cluster,shell,print-generated -wp-prover why3 -wp-warn-key "pedantic-assigns=inactive"
>>>>>>> origin/master
   OPT: -wp-model Typed -wp -wp-gen -wp-print -then -wp-model Typed+ref -wp -wp-gen -wp-print
*/

/* run.config_qualif
   OPT: -wp-msg-key print-generated -wp-model Typed -then -wp -wp-model Typed+ref
*/

//@ predicate P(integer a);

//@ ensures P(\result);
int f(int *p,int k) { return p[k]; }
