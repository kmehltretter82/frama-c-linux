/* This tests a thread created suspended, then starting by another thread. */
/* TODO: check that the cfgs are correct */

#include "mthread_pthread.h"
#define NULL (void*)0

pthread_t job1, job2;


pthread_t thread_create(pthread_t *thread, const pthread_attr_t *attr,
                      void *(*start_routine)(void *), void *arg) {
  *thread = __FRAMAC_THREAD_CREATE(thread, start_routine, arg);
  return *thread;
}

int thread_start(pthread_t thread) {
  __FRAMAC_THREAD_START(thread);
  return 0;
}

void *f1(void * p) {
  return NULL;
}

void *f2(void * p) {
  thread_start(job1);
  return NULL;
}

int main() {
  thread_create(&job1, NULL, f1, NULL);
  thread_create(&job2, NULL, f2, NULL);
  __FRAMAC_THREAD_START(job2);
  
  return 0;
}
