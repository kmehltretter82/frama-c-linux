typedef int value_type; 
typedef int size_type; 
typedef int bool; 

/*@ predicate IsValidRange(value_type* a, integer n) = 
  @   (0 <= n) && \valid(a+(0..n-1));
  @*/

/*@ predicate IsEqual{A,B}(value_type* a, integer n, value_type* b) = 
  @   \forall integer i; 0 <= i < n ==> \at(a[i], A) == \at(b[i], B) ; 
  @*/ 
