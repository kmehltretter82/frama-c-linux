/* run.config
 PLUGIN:
 MODULE: @PTEST_NAME@
   EXECNOW: LOG my_visitor_sav.res LOG my_visitor_sav.err BIN my_visitor.sav @frama-c@ @PTEST_FILE@ -main f -save @PTEST_DIR@/@PTEST_NAME@.sav > @PTEST_DIR@/result/@PTEST_NAME@_sav.res 2> @PTEST_DIR@/result/@PTEST_NAME@_sav.err
   OPT: -load @PTEST_DIR@/@PTEST_NAME@.sav -no-my-visitor -print
 MODULE:
   OPT: -load @PTEST_DIR@/@PTEST_NAME@.sav -print
*/
int f() {
  int y = 0;
  y++;
  /*@ assert y == 1; */
  return 0;
}
