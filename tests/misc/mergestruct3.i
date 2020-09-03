/* run.config
   OPT: -print -journal-disable mergestruct1.i mergestruct2.i
   OPT: -print -journal-disable mergestruct2.i mergestruct1.i
*/
struct s { float a; } s2;

void f(void)
{
  s2.a = 1.0;
}
