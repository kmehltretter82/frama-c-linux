/* run.config
   DONTRUN:
*/

/* run.config_qualif
   CMD: @frama-c@ -no-autoload-plugins -load-module wp -wp-share ./share -wp-msg-key shell -wp-warn-key pedantic-assigns=inactive
   OPT: -wp -wp-prover alt-ergo -wp-session shall_not_exists_dir -wp-cache offline -wp-no-cache-env
   COMMENT: The session directory shall not be created
 */

//@ ensures \false ;
void f(void) { return; }
