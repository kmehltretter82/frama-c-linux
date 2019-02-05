/*@ 
  requires IsValidRange(a, m); 
  requires IsValidRange(b, n);
  assigns \nothing;

  behavior has_match: 
    assumes HasSubRange(a, m, b, n); 
    ensures (n == 0 || m ==0) ==> \result == 0; 
    ensures 0 <= \result <= m-n; 
    ensures IsEqual{Here,Here}(a+\result, n, b); 
    ensures !HasSubRange(a, \result+n-1, b, n);

  behavior no_match: 
    assumes !HasSubRange(a, m, b, n); 
    ensures \result == m;

  complete behaviors; 
  disjoint behaviors;
*/
size_type search(const value_type* a, size_type m, const value_type* b, size_type n);