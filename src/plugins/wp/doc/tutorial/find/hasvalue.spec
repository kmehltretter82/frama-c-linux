/*@ 
  predicate HasValue{A}(value_type* a, integer n, value_type val) = 
    \exists integer i; 0 <= i < n && a[i] == val; 
*/
