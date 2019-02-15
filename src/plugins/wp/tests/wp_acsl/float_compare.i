/*@ lemma test_float_compare:
      \forall float x,y;
      \is_finite(x) && \is_finite(y) ==>
      \le_float(x,y) ==> \lt_float(x,y) || \eq_float(x,y);
*/

/*@ lemma test_double_compare:
      \forall double x,y;
      \is_finite(x) && \is_finite(y) ==> \le_double(x,y) ==>
         \lt_double(x,y) || \eq_double(x,y);
*/
