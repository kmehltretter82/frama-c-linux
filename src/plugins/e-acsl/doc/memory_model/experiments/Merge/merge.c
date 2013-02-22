/* run.config
   OPT: -pc -pc-trace -pc-tests -kernel-debug 0 -verbose 0 -pc-deter -pc-trace-preconds -pc-trace-simpred -pc-trace-result -pc-k-path 2 -main Merge
*/




/*@ ensures \forall int i; 0 <= i < (l1+l2-1) ==> t3[i] <= t3[i+1];
  @*/
void Merge (int t1[], int t2[], int t3[], int l1, int l2) {
  int i = 0;
  int j = 0;
  int k = 0;

  while (i < l1 && j < l2) {
    //@ assert i < l1;
    //@ assert j < l2;
    if (t1[i] < t2[j]) {
      //@ assert t1[i] < t2[j];
      t3[k] = t1[i];
      //@ assert t3[k] == t1[i];
      //@ ghost int tmp = i;
      i++;
      //@ assert tmp + 1 == i;
    }
    else {
      //@ assert t1[i] >= t2[j];
      t3[k] = t2[j];
      //@ assert t3[k] == t2[j];
      //@ ghost int tmp = j;
      j++;
      //@ assert tmp + 1 == j;
    }
    //@ ghost int tmp = k;
    k++;
    //@ assert tmp + 1 == k;
  }
  //@ assert i >= l1 || j >= l2;
  while (i < l1) {
    //@ assert i < l1;
    t3[k] = t1[i];
    //@ assert t3[k] == t1[i];
    //@ ghost int tmp1 = i;
    //@ ghost int tmp2 = k;
    i++;
    //@ assert tmp1 + 1 == i;
    k++;
    //@ assert tmp2 + 1 == k;
  }
  //@ assert i >= l1;
  while (j < l2) {
    //@ assert j < l2;
    t3[k] = t2[j];
    //@ assert t3[k] == t2[j];
    //@ ghost int tmp1 = j;
    //@ ghost int tmp2 = k;
    j++;
    //@ assert tmp1 + 1 == j;
    k++;
    //@ assert tmp2 + 1 == k;
  }
  //@ assert j >= l2;
}
