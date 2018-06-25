/*@
  requires IsValidRange(a, n);

  assigns a[0..n-1];

  ensures \forall integer i; 0 <= i < n ==> a[i] == val;
*/
void fill(value_type* a, size_type n, value_type val);
