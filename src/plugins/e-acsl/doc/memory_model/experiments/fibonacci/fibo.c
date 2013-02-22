
/*@ requires n >= 3;
  @ ensures t[0] == 1;
  @ ensures t[1] == 1;
  @ ensures \forall int i; 2 <= i < n ==> t[i-2] + t[i-1] == t[i];
  @*/
void fibo(int *t, int n) {
  int i;
  t[0] = t[1] = 1;
  //@ assert t[0] == 1;
  //@ assert t[1] == 1;

  //@ assert n >= 3;
  for(i = 2; i < n; ) {
    //@ assert 2 <= i < n;
    t[i] = t[i-1] + t[i-2];
    //@ assert t[i] == t[i-1] + t[i-2];
    //@ ghost int old_i = i;
    i++;
    //@ assert old_i + 1 == i;
  }
  //@ assert i >= n;
}
