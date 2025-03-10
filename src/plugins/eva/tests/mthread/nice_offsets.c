#include "mthread_pthread.h"
#include "mthread_queue.h"
#define NULL ((void*)0)

struct s0 {
  int a0;
  int b0;
  int c0;
};

typedef struct {
  int a1;
  struct s0 b1[5];
  int c1;
} s1;

s1 t[3];

void main() {
  pthread_mutex_init(&t[0].a1 , NULL);
  pthread_mutex_init(&t[1].b1[2].a0 , NULL);
  pthread_mutex_init(&t[1].b1[4].b0 , NULL);
  pthread_mutex_init(&t[2].c1 , NULL);
}
