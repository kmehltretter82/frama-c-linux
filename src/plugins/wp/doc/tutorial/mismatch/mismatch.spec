/*@ 
  requires IsValidRange(a, n); 
  requires IsValidRange(b, n); 

  assigns \nothing; 
  
  behavior all_equal: 
    assumes IsEqual{Here,Here}(a, n, b); 
    ensures \result == n; 
   
  behavior some_not_equal: 
    assumes !IsEqual{Here,Here}(a, n, b); 
    ensures 0 <= \result < n; 
    ensures a[\result] != b[\result]; 
    ensures IsEqual{Here,Here}(a, \result, b); 

  complete behaviors; 
  disjoint behaviors; 
*/ 
size_type mismatch(const value_type* a, size_type n, const value_type* b); 
