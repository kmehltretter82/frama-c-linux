#include "__fc_builtin.h"

/*@
  axiomatic P {
    predicate P(int x);
  }

 @*/

int z;

void f (int *x, int *y){
  *x = *x+1;
  /*@ assert P(*x) && P(*y) && P(z); @*/
}

void g (int *x, int *y){
  *x = *x+1;
  /*@ assert P(*x) && P(*y) && P(z); @*/
}

void main(){
  int x = Frama_C_interval(2,1000);
  int y = Frama_C_interval(2,1000);
  z = Frama_C_interval(2,1000);
  f(&z,&z);
  g(&x,&y);
}
