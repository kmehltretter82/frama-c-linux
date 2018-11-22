/*@ 
  requires n>0 ;
  requires IsValidRange(a, n);
  assigns \nothing;

  ensures \forall integer i; 0 <= i <= n-1 ==> \result >= a[i];
  ensures \exists integer e; 0 <= e <= n-1 &&  \result == a[e];
*/
size_type max_seq(const value_type* a, size_type n);
