
#include "stdlib.h"

/*@ requires n >= 3;
  @ requires \valid(t+(0..n-1));
  @ ensures t[0] == 1;
  @ ensures t[1] == 1;
  @ ensures \forall int i; 2 <= i < n ==> t[i-2] + t[i-1] == t[i];
  @*/
void fibo(int *t, int n) {
  int i;
  t[0] = t[1] = 1;

  /*@ loop invariant \forall int k; 2 <= k < i ==> t[k] == t[k-1] + t[k-2];
    @ loop assigns i, *(t+(2..n-1));
    @ loop variant n-i;
    @*/
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


/*@ ensures \result >= x;
  @ assigns \nothing;
  @*/
int unbounded_random(int x);

void driver() {
  int n = unbounded_random(3);
  int * t = malloc(n * sizeof(int));
  fibo(t, n);
  free(t);
}

