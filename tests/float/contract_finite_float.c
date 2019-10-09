/* run.config*
   OPT: -eva @EVA_CONFIG@ -warn-special-float none -contract-finite-float
*/

#include <math.h>


/*@ 
    assigns \result \from x;
    behavior normal:
      assumes finite_arg: \is_finite(x);
      ensures res_finite: \is_finite(\result);
      ensures positive_result: \result >= 0.;
      ensures equal_magnitude_result: \result == x || \result == -x;
    behavior nan:
      assumes nan_arg: \is_NaN(x);
      ensures  res_nan: \is_NaN(\result);
    behavior infinite:
      assumes infinite_arg: \is_infinite(x);
      ensures  res_plus_infinity: \is_plus_infinity(\result);
*/
extern double myfabs(double x);

volatile double x;

int main(){
  double z = x;
  double y = myfabs(x);
}
