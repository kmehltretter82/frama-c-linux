/*@
  ensures LessIrreflexivity: 
    \forall value_type a; !(a < a);
  ensures LessAntisymetry:   
    \forall value_type a, b; (a < b) ==> !(b < a);
  ensures LessTransitivity:
    \forall value_type a, b, c; (a < b) && (b < c) ==> (a < c);
*/
void less(void) { }
