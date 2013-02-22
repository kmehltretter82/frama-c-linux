/* run.config
   COMMENT: BsearchPrecond
   OPT: -pc -pc-trace -pc-tests -kernel-debug 0 -verbose 0 -pc-deter -pc-trace-preconds -pc-trace-simpred -pc-trace-result -main Bsearch
*/
/* Binary search of a given element in a given ordered array
   returning 1 if the element is present and 0 if not.
   This example is like Bsearch
   but gives an example of 
   a precondition coded in C */

/*@ ensures (\exists int i; 0 <= i < 10 && A[i] == elem) <==> \result;
  @*/
int Bsearch( int A[10], int elem)
{
  int low, high, mid, found ;
  
  low = 0 ;
  high = 9 ;
  found = 0 ;
  while( ( high > low ) )
    { 
      //@ assert high > low;
      mid = (low + high) / 2 ;
      //@ assert mid == (low+high) / 2;
      if( elem == A[mid] )  {
	//@ assert elem == A[mid];
	found = 1;
	//@ assert found == 1;
      }
      if( elem > A[mid] ) {
	//@ assert elem > A[mid];
        low = mid + 1 ;
	//@ assert low == mid + 1;
      }
      else {
	//@ assert elem <= A[mid];
        high = mid - 1;
	//@ assert high == mid - 1;
      }
    }  
  //@ assert high <= low;
  mid = (low + high) / 2 ;
  //@ assert mid == (low+high) / 2;
  
  if( ( found != 1)  && ( elem == A[mid]) ) {
    //@ assert found != 1 && elem == A[mid];
    found = 1; 
    //@ assert found == 1;
  }
  
  return found ;
}

/* C precondition of function Bsearch
   This must have the name of the tested function suffixed with _precond
   and have the same number of arguments with the same types.
   It must return 1 if the parameter values satisfy the precondition and 0 if not */
int Bsearch_precond( int A[10], int elem) {
  int i;
  for (i = 0; i < 9; i++){
    if (A[i]>A[i+1])
      return 0 ;             /* not ordered by increasing value */
  }
  return 1;
}
