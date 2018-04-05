#include "__fc_builtin.h"

int main() {

  /*
    The expression is a parabola p
      where p([0.;64.]) = [0.;64.] and p([64.;128.]) = [0.;64.].
      For any value x<0, p(x) < x;
      For any value 128.<x, p(x) < -x;
   */

  double f1 = Frama_C_double_interval(0.,1./64.);

  //@ loop widen_hints f1, 71.;
  for(int i = 0; i < 100; i++){
    f1 = (64*64 - (f1 - 64) * (f1 - 64))/64;
  }

  double f2 = Frama_C_double_interval(-1./64.,-0);

  //@ loop widen_hints f2, -80.;
  for(int i = 0; i < 100; i++){
    f2 = -(64*64 - (-f2 - 64) * (-f2 - 64))/64;
  }

  double f3 = Frama_C_double_interval(0.,1./64.);

  for(int i = 0; i < 100; i++){
    f3 = (64*64 - (f3 - 64) * (f3 - 64))/64;
  }

  return 0;
}
