/* run.config
   FILTER: sed -E -e '/atanf_/ s/([0-9][.][0-9]{6})[0-9]+/\1/g'
   STDOPT: #"-warn-special-float none" #"-cpp-extra-args=\"-DNONFINITE\"" #"-eva-slevel 4"
*/
#include <math.h>
const double pi = 3.14159265358979323846264338327950288;
const double half_pi = 1.57079632679489661923132169163975144;
const double e = 2.718281828459045090795598298427648842334747314453125;
volatile double top;
const float f_pi = 3.14159265358979323846264338327950288F;
const float f_half_pi = 1.57079632679489661923132169163975144F;
const float f_e = 2.718281828459045090795598298427648842334747314453125F;
volatile float f_top;
const long double ld_pi = 3.14159265358979323846264338327950288L;
const long double ld_half_pi = 1.57079632679489661923132169163975144L;
const long double ld_e = 2.718281828459045090795598298427648842334747314453125L;
volatile long double ld_top;
const double zero = 0.0;
const double minus_zero = -0.0;
const double one = 1.0;
const double minus_one = -1.0;
const double large = 1e38;
#ifdef NONFINITE
const double huge_val = HUGE_VAL;
const float huge_valf = HUGE_VALF;
const long double huge_vall = HUGE_VALL;
const float infinity = INFINITY;
#endif
const double fp_ilogb0 = FP_ILOGB0;
const double fp_ilogbnan = FP_ILOGBNAN;
volatile int int_top;

#define TEST_VAL_CONST(type,f,cst) type f##_##cst = f(cst)
#define TEST_FUN_CONSTS(type,f,prefix)          \
  TEST_VAL_CONST(type,f,prefix##pi);            \
  TEST_VAL_CONST(type,f,prefix##half_pi);       \
  TEST_VAL_CONST(type,f,prefix##e);             \
  TEST_VAL_CONST(type,f,zero);                  \
  TEST_VAL_CONST(type,f,minus_zero);            \
  TEST_VAL_CONST(type,f,one);                   \
  TEST_VAL_CONST(type,f,minus_one);             \
  TEST_VAL_CONST(type,f,large);                 \
  TEST_VAL_CONST(type,f,prefix##top)

// tests functions with 2 arguments, where the first one changes,
// but the second one is fixed by the caller.
// suffix prevents redeclaring variables with the same name
#define TEST_VAL2_FST_CONST(type,f,cst,snd_arg,suffix) type f##_##cst##suffix = f(cst,snd_arg)
#define TEST_FUN2_FST_CONSTS(type,f,prefix,snd_arg,suffix)    \
  TEST_VAL2_FST_CONST(type,f,prefix##pi,snd_arg,suffix);            \
  TEST_VAL2_FST_CONST(type,f,prefix##half_pi,snd_arg,suffix);  \
  TEST_VAL2_FST_CONST(type,f,prefix##e,snd_arg,suffix);        \
  TEST_VAL2_FST_CONST(type,f,zero,snd_arg,suffix);             \
  TEST_VAL2_FST_CONST(type,f,minus_zero,snd_arg,suffix);       \
  TEST_VAL2_FST_CONST(type,f,one,snd_arg,suffix);              \
  TEST_VAL2_FST_CONST(type,f,minus_one,snd_arg,suffix);        \
  TEST_VAL2_FST_CONST(type,f,large,snd_arg,suffix);            \
  TEST_VAL2_FST_CONST(type,f,prefix##top,snd_arg,suffix)

int main() {
  TEST_FUN_CONSTS(double,atan,);
  TEST_FUN_CONSTS(float,atanf,f_);
  TEST_FUN_CONSTS(long double,atanl,ld_);
  TEST_FUN_CONSTS(double,fabs,);
  TEST_FUN_CONSTS(float,fabsf,f_);
  TEST_FUN_CONSTS(long double,fabsl,ld_);
  int exponent;
  TEST_FUN2_FST_CONSTS(double,frexp,,&exponent,);
  TEST_FUN2_FST_CONSTS(float,frexpf,f_,&exponent,);
  TEST_FUN2_FST_CONSTS(long double,frexpl,ld_,&exponent,);
  TEST_FUN2_FST_CONSTS(double,ldexp,,10,);
  TEST_FUN2_FST_CONSTS(float,ldexpf,f_,10,);
  //TEST_FUN2_FST_CONSTS(long double,ldexpl,ld_,10,);
  TEST_FUN2_FST_CONSTS(double,ldexp,,0,_zero);
  TEST_FUN2_FST_CONSTS(float,ldexpf,f_,0,_zero);
  //TEST_FUN2_FST_CONSTS(long double,ldexpl,ld_,0,_zero);
  TEST_FUN2_FST_CONSTS(double,ldexp,,-5,_minus5);
  TEST_FUN2_FST_CONSTS(float,ldexpf,f_,-5,_minus5);
  //TEST_FUN2_FST_CONSTS(long double,ldexpl,ld_,-5,_minus5);
  TEST_FUN2_FST_CONSTS(double,ldexp,,100000,_huge);
  TEST_FUN2_FST_CONSTS(float,ldexpf,f_,100000,_huge);
  //TEST_FUN2_FST_CONSTS(long double,ldexpl,ld_,100000,_huge);

#ifdef NONFINITE
  int r;
  r = isfinite(pi);
  //@ assert r;
  r = isfinite(large);
  //@ assert r;
  r = isfinite(0.0f);
  //@ assert r;
  r = isfinite(huge_val);
  //@ assert !r;
  r = isfinite(-INFINITY);
  //@ assert !r;
  r = isfinite(NAN);
  //@ assert !r;
#endif
}
