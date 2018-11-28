/*@
  requires IsValidRange(a, n);
  requires val + n < 2147483647 ; // INT_MAX

  assigns a[0..n-1];
  
  ensures \forall integer k; 0 <= k < n ==> a[k] == val + k;
*/
void iota(value_type* a, size_type n, value_type val);