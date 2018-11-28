/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);
  
  assigns b[0..(n-1)];
  
  ensures \forall integer i; 0 <= i < n ==> b[i] == a[n-1-i];
*/
void reverse_copy(const value_type* a, size_type n, value_type* b);
