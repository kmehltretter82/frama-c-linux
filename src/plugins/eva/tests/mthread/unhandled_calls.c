/* run.config*
 EXIT: 1
   STDOPT:
 */
/* This example tests a very specific error message withing message, a call
   through a function pointer calls simultaneously a standard function
   and an mthread function. Indirectly, this also tests option
   -mt-inline-callbacks */
#include "mthread_pthread.h"
#include "mthread_queue.h"
#define NULL ((void*)0)
void** q;
pthread_t        th1, th2;
int random(void);
void *t (void *_) {return NULL;}

int f1(void * p, int i) {
  pthread_create( &th2, NULL, t, NULL);
  return 0;
}

int f2(void * p, int i) {
  pthread_create( &th1, NULL, t, NULL);
  return 0;
}

void main () {
  int (*p)(void *, int);

  if (random ())
    p = &f1;
  else
    p = &queuecreate;

  (*p)(&q,1);

  if (random ())
    p = &f2;
  else
    p = &__FRAMAC_QUEUE_INIT;

  (*p)(&q,1);

}
