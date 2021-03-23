/* run.config*
 EXIT: 1
   STDOPT:
*/


void f(void) {}

int main()
  {
  void (*p)(void) = &f ;
  p = 1 ;
  *p = 1 ;
  return 0 ;
  }
