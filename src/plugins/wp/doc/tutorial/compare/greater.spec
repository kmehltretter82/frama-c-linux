/*@ 
  ensures Greater:
    \forall value_type a, b; (a > b) <==> (b < a); 
  ensures LessOrEqual:
    \forall value_type a, b; (a <= b) <==> !(b < a);
  ensures GreaterOrEqual: 
    \forall value_type a, b; (a >= b) <==> !(a < b);
*/
void greater(void) { }
