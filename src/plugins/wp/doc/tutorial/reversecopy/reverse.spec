/*@
  requires IsValidRange(a, n);
 
  assigns a[0..(n-1)];
  
  ensures \forall integer i; 0 <= i < n ==> 
            a[i] == \old(a[n-1-i]);
*/
void reverse(value_type* a, size_type n);
