/* run.config*
 MODULE: @PTEST_NAME@
   OPT: -eva -main f -then-on change_main -main g -eva
*/

int f(int x) { return x; }
