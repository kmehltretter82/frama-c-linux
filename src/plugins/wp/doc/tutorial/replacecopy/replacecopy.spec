/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);
  requires \separated(a+(0..n-1), b+(0..n-1));

  assigns b[0..(n-1)];

  ensures \forall integer j; 0 <= j < n ==>
           (a[j] == old_val && b[j] == new_val) ||
	   (a[j] != old_val && b[j] == a[j]);
  ensures \result == n;
*/
size_type replace_copy(const value_type* a, size_type n, 
                       value_type* b,
		       value_type old_val, value_type new_val);
