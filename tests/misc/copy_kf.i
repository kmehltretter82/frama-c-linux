/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

/*@ requires \valid(p); assigns *p; ensures *p == x; */
void g(int* p, int x);

/*@ requires 0 <= x <= 10;
    ensures \result == 2 * x;
*/
int f(int x) { int y; g(&y,x); return x + y; }
