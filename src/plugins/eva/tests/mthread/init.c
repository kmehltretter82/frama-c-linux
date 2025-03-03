/* run.config
   STDOPT: +"-pp-annot"
*/
/* This example tests the various way a structure can be named:
   with a pointer, with a string, without any indication (in
   this last case, only once per statement, or with a proper
   unrolling) */
#include "mthread_pthread.h"
#define NULL ((void*)0)
#define N 3

int  locks[N];
char (*names[2*N]) = { "mu1", "mu2", "mu3", "mu4", "mu5", "mu6" };


int mutex_init(void* mname) {
  return Frama_C_mutex_init(mname);
}

void main() {
  int i ;

  for(i=0;i<N;i++)
    mutex_init(&locks[i]);

  for(i=0;i<N;i++)
    mutex_init(names[i]);

  /*@ loop unfold N; */
  for(i=0;i<N;i++) {
    int m = mutex_init(NULL);
    Frama_C_mthread_name_mutex(m, names[i+3]);
  }

  // We really need to unroll the loop
  for(i=0;i<N;i++)
    mutex_init(NULL);
}
