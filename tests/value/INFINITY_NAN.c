/* run.config*
  STDOPT: +"-warn-special-float none"
*/

#include <math.h>

int main1(){
  float infinity_f = INFINITY;
  Frama_C_show_each(infinity_f);
  /*@ assert \eq_float(infinity_f,INFINITY); @*/
  double infinity_d = HUGE_VAL;
  if(infinity_f == infinity_d) {
    return 1;
  } else {
    /*@ assert \false; @*/
    return 0;
  }
}


volatile float nondet;

int main2(){
  float nan_f = nondet;
  Frama_C_show_each(nan_f);
  /*@ assert \is_NaN(nan_f); @*/
  double infinity_d = HUGE_VAL;
  if(nan_f == infinity_d) {
    /*@ assert \false; @*/
    return 0;
  } else {
    return 1;
  }
}


int main(){
  return (main1 () && main2 ());
}
