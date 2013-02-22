/* run.config
   COMMENT: Bsort
   OPT: -pc -pc-trace -pc-tests -kernel-debug 0 -verbose 0 -pc-deter -pc-trace-preconds -pc-trace-simpred -pc-trace-result -main bsort
*/
/* Bubble sort of a given array 'table' of a given length 'l' in descending order. This example is interesting because of its
   - variable dimension input array
   - loop with a variable number of iterations,
     which is limited by limiting the array dimension
   - oracle which does not sort but checks the result is ordered */

/*@ ensures \forall int k; 0 <= k < l-1 ==> table[k] >= table[k+1];
  @*/
void bsort (int * table, int l) 
{
  int i, temp, nb;
  char fini;
  fini = 0;
  nb = 0;
  //@ assert l >= 0;
  //@ assert fini == 0;
  //@ assert nb == 0;
  while ( !fini && (nb < l-1)){
    //@ assert fini == 0;
    //@ assert nb < l-1;
    fini = 1;
    //@ assert fini == 1;
    for (i=0 ; i<l-1 ; )   {
      //@ assert 0 <= i < l-1;
      if (table[i] < table[i+1]){
	//@ assert table[i] < table[i+1];
	fini = 0;
	//@ assert fini == 0;
	temp = table[i];
	//@ assert temp == table[i];
	table[i] = table[i + 1];
	//@ assert table[i] == table[i+1];
	table[i + 1] = temp;
	//@ assert table[i+1] == temp;
      }
      //@ ghost int old_i = i;
      i++;
      //@ assert old_i + 1 == i;
    }
    //@ assert i >= l-1;
    //@ ghost int old_nb = nb;
    nb++;
    //@ assert old_nb + 1 == nb;
  }
  //@ assert fini == 1 || nb >= l-1;
}
