/* This example tests the various way a structure can be named:
   with a pointer, with a string, without any indication */
#include "mthread_pthread.h"
#define NULL ((void*)0)
#define N 3

int  locks[N];
char (*names[3*N]) =
  { "mu1", "mu2", "mu3", "mu4", "mu5", "mu6", "mu7", "mu8", "mu9" };


int mutex_init(void* mname) {
  return Frama_C_mutex_init(mname);
}

void main() {
  int i ;

  for(i=0;i<N;i++)
    mutex_init(&locks[i]);

  for(i=0;i<N;i++)
    mutex_init(names[i]);

  //@ loop unfold 2*N;
  for(i=0;i<2*N;i++)
    if (i >= N)
      mutex_init(names[i]);

  for(i=0;i<3*N;i++)
    if (i >= 2*N)
      mutex_init(names[i]);

  // Warning: the same mutex is repeatedly created
  for(i=0;i<N;i++)
    mutex_init(NULL);
}
