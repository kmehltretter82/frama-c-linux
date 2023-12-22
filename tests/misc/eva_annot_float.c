/* run.config
   PLUGIN: @EVA_PLUGINS@
   OPT: -eva -eva-precision 2 -eva-annot main -print
*/

/* -------------------------------------------------------------------------- */
/* --- Testing EVA Annotations                                            --- */
/* -------------------------------------------------------------------------- */

//@ ghost int world;
double a[20];

/*@
  ensures \is_finite(\result);
  ensures 0.0 <= \result <= 100.0;
  assigns \result,world \from world;
*/
double value(void);

double main(void) {
  double s = 0;
  for (int i = 0; i < 20; i++) {
    double v = value();
    a[i] = v;
    s += v;
  }
  return s;
}

/* -------------------------------------------------------------------------- */
