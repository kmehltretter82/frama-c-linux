/*@
  predicate 
    SwapValues{L1,L2}(value_type* a, size_type i, size_type j) =
      0 <= i && 0 <= j &&
      \at(a[i],L1) == \at(a[j],L2) &&
      \at(a[j],L1) == \at(a[i],L2) &&
      (\forall integer k; 0 <= k && k != i && k != j ==>
	  \at(a[k],L1) == \at(a[k],L2));
*/

/*@
  requires IsValidRange(a, n);
  requires 0 <= i < n;
  requires 0 <= j < n;

  assigns a[i];
  assigns a[j];

  ensures SwapValues{Old,Here}(a, i, j);
*/
void swap_values(value_type* a, size_type n,
                 size_type   i, size_type j);