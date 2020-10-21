/* run.config
   DONTRUN:
*/

/* run.config_qualif
   CMD: @frama-c@ -wp-msg-key shell @OPTIONS@
   OPT: -wp -wp-prover alt-ergo -wp-session shall_not_exists_dir -wp-cache offline -wp-no-cache-env
   COMMENT: The session directory shall not be created
 */

//@ ensures \false ;
void f(void) { return; }
