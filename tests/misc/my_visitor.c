/* run.config
CMXS: @PTEST_NAME@
EXECNOW: LOG my_visitor_sav.res LOG my_visitor_sav.err BIN my_visitor.sav @frama-c@ @PTEST_FILE@ -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} -main f -save @PTEST_NAME@.sav > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
OPT: -load %{dep:@PTEST_NAME@.sav} -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} -no-my-visitor -print
OPT: -load %{dep:@PTEST_NAME@.sav} -no-autoload-plugins -print
*/
int f() {
  int y = 0;
  y++;
  /*@ assert y == 1; */
  return 0;
}
