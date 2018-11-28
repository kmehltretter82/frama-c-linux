/*@
  predicate 
    RemoveCopy{L}(value_type* a, integer n,
	          value_type* b, integer m, value_type v) =
      m == WhitherRemove(a, v, n) &&
      \forall integer i;
        0 <= i < n && a[i] != v ==> b[WhitherRemove(a, v, i)] == a[i];
*/

/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);
  requires \separated(a+(0..n-1), b+(0..n-1));

  assigns b[0..n-1];
  
  ensures \forall integer k; \result <= k < n ==> b[k] == \old(b[k]);

  ensures RemoveCopy(a, n, b, \result, val);
*/
size_type remove_copy(const value_type* a, size_type n, 
                      value_type* b, value_type val);