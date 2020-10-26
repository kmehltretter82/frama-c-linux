/* run.config
MODULE: logic_env_script
STDOPT: +"-no-print"
*/

//@ predicate foo(integer x) = x == 0;

int X;

//@ predicate bar{L} = X == 0;
