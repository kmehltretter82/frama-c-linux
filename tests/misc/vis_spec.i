/* run.config
   CMXS: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

//@ assigns \nothing;
void g (void) ;

//@ assigns \nothing;
void f () { g(); }

