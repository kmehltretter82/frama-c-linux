/*@ 
  requires IsValidRange(a, n); 
  requires IsSorted(a, n);

  assigns \nothing;

  ensures 0 <= \result <= n; 
  ensures \forall integer k; 0 <= k < \result ==> a[k] <= val; 
  ensures \forall integer k; \result <= k < n ==> val < a[k];
*/
size_type upper_bound(const value_type* a, size_type n, value_type val);
