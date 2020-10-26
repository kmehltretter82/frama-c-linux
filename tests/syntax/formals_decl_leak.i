/* run.config
MODULE: @PTEST_NAME@
STDOPT: +"%{dep:@PTEST_NAME@_1.i}"
*/

void f(int x);

void g() { f(3); }
