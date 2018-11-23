/*@
  predicate 
    UniqueCopy{L}(value_type* a, integer n,
	          value_type* b, integer m) =
      (n == 0 ==> m == 0) && 
      (n >= 1 ==> m-1 == WhitherUnique(a, n-1)) &&
      \forall integer i;
        0 <= i < n ==> a[i] == b[WhitherUnique(a,i)];
*/

/*@
  requires IsValidRange(a, n);
  requires IsValidRange(b, n);
  requires \separated(a+(0..n-1), b+(0..n-1));

  assigns b[0..n-1];
  
  ensures \forall integer k; \result <= k < n ==> b[k] == \old(b[k]);

  ensures 0 <= \result <= n;
  ensures UniqueCopy(a, n, b, \result);
*/
size_type unique_copy(const value_type* a, 
                      size_type n, value_type* b);