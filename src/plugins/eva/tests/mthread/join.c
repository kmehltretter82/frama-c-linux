#include "mthread_pthread.h"
#include "mthread_queue.h"
#define NULL ((void*)0)


pthread_mutex_t*  lock;
pthread_t        th1;
pthread_t        th2;

void *t1 (void* _) {
  pthread_exit((void*) 1);
}

void *t2 (void* _) {
  pthread_exit((void*) 2);
}


int main () {
  pthread_create( &th1, NULL, t1, NULL);
  pthread_create( &th2, NULL, t2, NULL);
}
