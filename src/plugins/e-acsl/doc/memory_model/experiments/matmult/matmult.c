/* MDH WCET BENCHMARK SUITE. File version $Id: matmult.c,v 1.3 2005/11/11 10:31:26 ael01 Exp $ */

/*----------------------------------------------------------------------*
 * To make this program compile under our assumed embedded environment,
 * we had to make several changes:
 * - Declare all functions in ANSI style, not K&R.
 *   this includes adding return types in all cases!
 * - Declare function prototypes
 * - Disable all output
 * - Disable all UNIX-style includes
 *
 * This is a program that was developed from mm.c to matmult.c by
 * Thomas Lundqvist at Chalmers.
 *----------------------------------------------------------------------*/

#define UPPERLIMIT 10

void 
Multiply(int ** A, int ** B, int ** Res)
/*
 * Multiplies arrays A and B and stores the result in ResultArray.
 */
{
  register int    Outer, Inner, Index;

  //@ ghost int old_Outer = -1; 
  for (Outer = 0; Outer < UPPERLIMIT; Outer++) {
    //@ assert old_Outer != Outer;
    //@ ghost old_Outer = Outer;
    //@ assert 0 <= Outer < 10;
    //@ ghost int old_Inner = -1;
    for (Inner = 0; Inner < UPPERLIMIT; Inner++) {
      //@ assert old_Inner != Inner;
      //@ ghost old_Inner = Inner;
      //@ assert 0 <= Inner < 10;
      Res[Outer][Inner] = 0;
      //@ assert Res[Outer][Inner] == 0;
      //@ ghost int old_Index = -1;
      for (Index = 0; Index < UPPERLIMIT; Index++) {
	//@ assert old_Index != Index;
	//@ ghost old_Index = Index;
	//@ assert 0 <= Index < 10;
	//@ ghost int res = Res[Outer][Inner];
	Res[Outer][Inner] += A[Outer][Index] * B[Index][Inner];
	//@ assert Res[Outer][Inner] == res + A[Outer][Index] * B[Index][Inner];
      }
      //@ assert Index == 10;
    }
    //@ assert Inner == 10;
  }
  //@ assert Outer == 10;
}
