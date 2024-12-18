/* run.config
   PLUGIN: @EVA_PLUGINS@
   OPT: -eva -eva-precision 2 -warn-special-float none -eva-annot main1,main2,main3 -print
*/

/* -------------------------------------------------------------------------- */
/* --- Testing EVA exported annotations                                   --- */
/* -------------------------------------------------------------------------- */

//@ ghost int world;
double a[20];

/*@
  ensures \is_finite(\result);
  ensures 0.0 <= \result <= 100.0;
  assigns \result,world \from world;
*/
double value(void);

double main1(void) {
  double s = 0;
  for (int i = 0; i < 20; i++) {
    double v = value();
    a[i] = v;
    s += v;
  }
  return s;
}

/*@
  ensures (\is_finite(\result) ∧ 0.0 <= \result <= 100.0) ∨ \is_NaN(\result);
  assigns \result,world \from world;
*/
double value_or_nan(void);

void main2(void) {
  for (int i = 0; i < 20; i++) {
    double v = value_or_nan();
    a[i] = v;
  }
}

/*@
  ensures \is_NaN(\result);
  assigns \result,world \from world;
*/
double nan(void);

void main3(void) {
  for (int i = 0; i < 20; i++) {
    double v = nan();
    a[i] = v;
  }
}

void main(void) {
  main1();
  main2();
  main3();
}

/* -------------------------------------------------------------------------- */
