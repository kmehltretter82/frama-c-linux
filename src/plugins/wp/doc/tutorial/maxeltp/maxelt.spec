/*@ 
  requires IsValidRange(a, n);
  assigns \nothing;

  behavior empty: 
    assumes n == 0; 
    ensures \result == 0;
  
  behavior not_empty: 
    assumes 0 < n; 
    ensures 0 <= \result < n;
    ensures IsMaximum(a, n, \result); 
    ensures IsFirstMaximum(a, \result);

  complete behaviors; disjoint behaviors;
*/
size_type max_element(const value_type* a, size_type n);
