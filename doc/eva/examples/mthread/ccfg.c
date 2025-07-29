#include <pthread.h>
#include <stddef.h>

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

//@ assigns *v, *(v+1) \from \nothing;
void g2(int* v);

void main(void) {
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
