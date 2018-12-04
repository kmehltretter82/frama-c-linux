/*@ 
  requires IsValidRange(a, n); 
  assigns \nothing; 
 
  behavior some:
    assumes HasValue(a, n, val); 
    ensures 0 <= \result < n; 
    ensures a[\result] == val; 
    ensures !HasValue(a, \result, val); 

  behavior none:
    assumes !HasValue(a, n, val); 
    ensures \result == n; 
 
  complete behaviors; 
  disjoint behaviors; 
*/
size_type find(const value_type* a, size_type n, value_type val) ;
