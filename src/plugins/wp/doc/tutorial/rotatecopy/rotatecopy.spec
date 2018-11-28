/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);
  requires \separated(a+(0..n-1), b+(0..n-1));
  requires 0 <= m <= n;

  assigns b[0..(n-1)];

  ensures IsEqual{Here,Here}(a, m, b+(n-m));
  ensures IsEqual{Here,Here}(a+m, n-m, b);  
*/
void rotate_copy(const value_type* a, size_type m, size_type n,
                 value_type* b);