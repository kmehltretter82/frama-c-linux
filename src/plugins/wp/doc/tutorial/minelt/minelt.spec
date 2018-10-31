/*@ 
  requires IsValidRange(a, n);
  assigns \nothing;

  behavior empty: 
    assumes n == 0; 
    ensures \result == 0;
  
  behavior not_empty: 
    assumes 0 < n; 
    ensures 0 <= \result < n;
    ensures \forall integer i; 0 <= i < n ==> a[\result] <= a[i]; 
    ensures \forall integer i; 0 <= i < \result ==> a[\result] < a[i];

  complete behaviors; 
  disjoint behaviors;
*/
size_type min_element(const value_type* a, size_type n);
