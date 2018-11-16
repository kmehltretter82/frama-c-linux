/*@ 
  requires IsValidRange(a, m); 
  requires IsValidRange(b, n); 
  assigns \nothing; 
 
  behavior found:
    assumes HasValueOf(a, m, b, n); 
    ensures (0 <= \result < m); 
    ensures HasValue(b, n, a[\result]);
    ensures !HasValueOf(a, \result, b, n); 

  behavior not_found:
    assumes !HasValueOf(a, m, b, n); 
    ensures \result == m; 
 
  complete behaviors; 
  disjoint behaviors; 
*/
size_type find_first_of(const value_type* a, size_type m,
                        const value_type* b, size_type n);
