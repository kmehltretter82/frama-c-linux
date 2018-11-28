/*@ 
  axiomatic Comparison {

  lemma LessIrreflexivity: 
    \forall value_type a; !(a < a);
  lemma LessAntisymetry:   
    \forall value_type a, b; (a < b) ==> !(b < a);
  lemma LessTransitivity:
    \forall value_type a, b, c; (a < b) && (b < c) ==> (a < c);

  lemma Greater:
    \forall value_type a, b; (a > b) <==> (b < a); 
  lemma LessOrEqual:
    \forall value_type a, b; (a <= b) <==> !(b < a);
  lemma GreaterOrEqual: 
    \forall value_type a, b; (a >= b) <==> !(a < b);

  } 
*/
