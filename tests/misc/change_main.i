/* run.config*
OPT: -eva -main f -load-script tests/misc/change_main.ml -then-on change_main -main g -eva
*/

int f(int x) { return x; }
