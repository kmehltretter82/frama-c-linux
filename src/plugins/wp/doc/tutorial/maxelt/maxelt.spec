/*@ 
  requires IsValidRange(a, n);
  assigns \nothing;

  behavior empty: 
    assumes n == 0; 
    ensures \result == 0;
  
  behavior not_empty: 
    assumes 0 < n; 
    ensures 0 <= \result < n;
    ensures \forall integer i; 0 <= i < n ==> a[i] <= a[\result]; 
    ensures \forall integer i; 0 <= i < \result ==> a[i] < a[\result];

  complete behaviors; 
  disjoint behaviors;
*/
size_type max_element(const value_type* a, size_type n);
