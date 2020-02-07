//@ requires 0 < Nb <= 8 ;
void acquire(int R,int Nb,int * Data)
{
  if ( (R & 0x0F00) >> 8 == Nb ) {
    int j = 0 ;
    /*@
      loop invariant RANGE: 0 <= j <= Nb ;
      loop assigns j, Data[0..7] ;
    */
    while (j < Nb) {
      Data[j] = 0 ;
      j++;
    }
  }
}
