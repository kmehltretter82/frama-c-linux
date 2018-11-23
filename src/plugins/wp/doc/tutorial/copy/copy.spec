/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);
  requires \separated(a+(0..n-1), b+(0..n-1));

  assigns b[0..n-1];
  
  ensures IsEqual{Here,Here}(a, n, b);

*/
void copy(const value_type* a, size_type n, value_type* b);