/*@ 
  predicate HasValueOf{A}(value_type* a, integer m, 
                          value_type* b, integer n) = 
    \exists integer i; 0 <= i < m && 
       HasValue{A}(b, n, \at(a[i],A)); 
*/
