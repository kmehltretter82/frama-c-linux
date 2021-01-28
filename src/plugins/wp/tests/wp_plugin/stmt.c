/* run.config
   PLUGIN: @PLUGIN@ report
   OPT: -then -report
*/
/* run.config_qualif
<<<<<<< HEAD
   PLUGIN: @PLUGIN@ report
   OPT: -then -report
   EXECNOW: LOG stmt.log LOG f.dot LOG f_default_for_stmt_2.dot LOG g.dot LOG g_default_for_stmt_11.dot @frama-c@ -wp-precond-weakening -wp -wp-warn-key pedantic-assigns=inactive -wp-model Dump -wp-out . -wp-msg-key shell 1> stmt.log
||||||| ac7807782d
   OPT: -load-module report -then -report
   EXECNOW: LOG stmt.log LOG f.dot LOG f_default_for_stmt_2.dot LOG g.dot LOG g_default_for_stmt_11.dot @frama-c@ -no-autoload-plugins -load-module wp -wp-precond-weakening -wp -wp-model Dump -wp-out tests/wp_plugin/result_qualif -wp-msg-key shell @PTEST_FILE@ 1> tests/wp_plugin/result_qualif/stmt.log
=======
   OPT: -load-module report -then -report
   EXECNOW: LOG stmt.log LOG f.dot LOG f_default_for_stmt_2.dot LOG g.dot LOG g_default_for_stmt_11.dot @frama-c@ -no-autoload-plugins -load-module wp -wp-precond-weakening -wp -wp-warn-key pedantic-assigns=inactive -wp-model Dump -wp-out tests/wp_plugin/result_qualif -wp-msg-key shell @PTEST_FILE@ 1> tests/wp_plugin/result_qualif/stmt.log
>>>>>>> origin/master
*/
/*@ ensures a > 0 ==> \result == a + b;
  @ ensures a <= 0 ==> \result == -1;
*/
int f(int a, int b) {

	/*@ exits \false;
 	  @ returns \result == a + b;
	  @ ensures a <= 0;
	  @ assigns \nothing;
	*/
	if (a > 0)
		return a + b;

	return -1;
}


/*@ ensures \result == a + b;
*/
int g(int a, int b) {

	/*@ exits \false;
 	  @ returns \result == a + b;
	  @ ensures \false;
	  @ assigns \nothing;
	*/
	return a + b;

}

/*@ ensures \result == (e ? a : b) ; */
int h(int e,int a,int b) {

	/*@ exits \false;
	  @ ensures \false;
	  @ assigns \nothing;
          @ behavior POS:
          @   assumes e ;
          @   returns \result == a;
          @ behavior NEG:
          @   assumes !e ;
          @   returns \result == b;
	*/
        if (e) return a; else return b;

}
