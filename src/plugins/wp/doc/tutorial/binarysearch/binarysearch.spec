/*@ 
  requires IsValidRange(a, n); 
  requires IsSorted(a, n);

  assigns \nothing;

  ensures \result <==> HasValue(a, n, val);
*/
bool binary_search(const value_type* a, size_type n, value_type val);
