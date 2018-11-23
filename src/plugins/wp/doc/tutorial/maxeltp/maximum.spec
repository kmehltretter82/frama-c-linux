/*@ 
  predicate IsMaximum{L}(value_type* a, integer n, integer max) =
    !(\exists integer i; 0 <= i < n && (a[max] < a[i]));

  predicate IsFirstMaximum{L}(value_type* a, integer max) = 
    \forall integer i; 0 <= i < max ==> a[i] < a[max];
*/