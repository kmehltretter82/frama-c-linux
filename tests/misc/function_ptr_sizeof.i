/* run.config*
   EXIT: 1
   STDOPT:
*/


void f(void) { }

int main(void)
  {
  void (*p)(void) = &f ;
  int x = sizeof(p) ;
  return sizeof(*p) ;
  }
