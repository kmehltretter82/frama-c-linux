/*@
  requires IsValidRange(a, n); 

  ensures \result == Count(a, val, 0, n);

  assigns \nothing; 
*/
size_type count(const value_type* a, size_type n, value_type val) ;
