/* run.config
CMXS: logic_env_script
OPT: -load-module %{dep:logic_env_script.cmxs}
*/

//@ predicate foo(integer x) = x == 0;

int X;

//@ predicate bar{L} = X == 0;
