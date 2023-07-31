/* This file is used to give an example of a cfg with many features */
#include "mthread_pthread.h"
#define NULL ((void*)0)

int random(void);

pthread_t  jobs[4];
int x, global1, global2[2];

void *fjob(void *_) {
  int r = global1 + global2[0] + global2[1];
  return NULL;
}

void g1(int* v, int i) {
  if (i<4)
    pthread_create(&jobs[i], NULL, fjob, NULL );
  else
    *v = 1;
}

void g2(int* v) {
  if (random())
    *v = 1;
  else
    *(v+1) = 2;
}

void main() {
  int i, arr[2];
  void (*pf)(int*, int) = &g1;

  g1(NULL, 0);
  g2(arr);
  for (i=1;i<5;i++)
    if (!x) {
      (*pf)(&global1, i);
      g2(global2);
    }
}
