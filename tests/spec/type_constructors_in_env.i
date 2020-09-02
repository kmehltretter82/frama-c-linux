/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

/*@ type foo = A | B; */

/*@ logic foo f(integer x) = x>=0 ? A : B; */
