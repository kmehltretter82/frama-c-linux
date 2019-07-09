/* run.config*
   OPT: -eva @EVA_CONFIG@ -warn-special-float none
*/

/* Tests on special float values NaN and infinites. */

volatile int rand;


/* All comparisons involving NaN are false, except for inequalities that are
   true. */
void nan_comparisons () {
  double n = 0.0 / 0.0;
  double d = rand ? -10. : 10.;
  int eq1 = (n == n) ? 1 : 0;
  int comp1 = (n < n) ? 1 : 0;
  int ne1 = (n != n) ? 1 : 0;
  int eq2 = (n == d) ? 1 : 0;
  int comp2 = (n < d) ? 1 : 0;
  int ne2 = (n != d) ? 1 : 0;
}


#include <math.h>

/* Tests the C and logic macros INFINITY and HUGE_VAL. */
void macro_infinity () {
  float infinity_f = INFINITY;
  Frama_C_show_each_infinity(infinity_f);
  /*@ assert \eq_float(infinity_f,INFINITY); @*/
  double infinity_d = HUGE_VAL;
  if(INFINITY != infinity_d)
    /*@ assert \false; @*/;
}

/* Tests the C and logic macros NAN. */
void macro_nan () {
  float nan_f = NAN;
  Frama_C_show_each_nan(nan_f);
  /*@ assert \is_NaN(nan_f); @*/
  /*@ assert \ne_float(nan_f,NAN); @*/
  /*@ assert \subset({nan_f},{NAN}); @*/
  if(NAN == nan_f)
    /*@ assert \false; @*/;
}


void main () {
  nan_comparisons ();
  macro_infinity ();
  macro_nan ();
}
