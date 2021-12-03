/* run.config
   OPT: -print @PTEST_DIR@/mergestruct1.i @PTEST_DIR@/mergestruct2.i
   OPT: -print @PTEST_DIR@/mergestruct2.i @PTEST_DIR@/mergestruct1.i
*/
struct s { float a; } s2;

void f(void)
{
  s2.a = 1.0;
}
