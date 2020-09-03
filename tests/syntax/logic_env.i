/* run.config
CMXS: logic_env_script
OPT: -load-module logic_env_script
*/

//@ predicate foo(integer x) = x == 0;

int X;

//@ predicate bar{L} = X == 0;
