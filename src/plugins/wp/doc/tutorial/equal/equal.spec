/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);

  assigns \nothing;

  ensures \result <==> IsEqual{Here,Here}(a, n, b);
*/
bool equal(const value_type* a, size_type n, const value_type* b);
