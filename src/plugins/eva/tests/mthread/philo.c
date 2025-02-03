/* run.config
   LOG: @LOG_MT_DOT_FILES_FILENAME@
   STDOPT: +"@LOG_MT_DOT_FILES_OPTS@"
*/
/* All-purpose example, implementing a slightly complexified version of the
   dining philosphers problems */

#include "mthread_pthread.h"
#include "mthread_queue.h"
#define NULL ((void*)0)
#define N 5


int end2 = 0;
pthread_mutex_t  locks[N];
pthread_t        jobs[N];
msgqueue_t queue;


int random(void);

void aux (int l, int r, int mess) {
  pthread_mutex_lock(locks+l);
  pthread_mutex_lock(locks+r);
  if (random() && mess != 2) {
    char buf[2];
    buf[0]=mess;
    end2 = 1;
    msgsnd(queue, buf, 2);
  }
  pthread_mutex_unlock(locks+r);
  pthread_mutex_unlock(locks+l);
}

void * job( void * k ) {
  int p = (int) k ;
  int l = p>0 ? p-1 : N-1 ;
  int r = p<N-1 ? p+1 : 0 ;

  while(1)
    aux(l, r, p+1);
}

int main() {
  int i ;
  char end[2];
  end[0]=0;

  for(i=0;i<N;i++)
    pthread_mutex_init( &locks[i] , NULL);

  queuecreate(&queue, 5);

  for(i=0;i<N;i++)
    pthread_create( &jobs[i], NULL, job, (void *) i );

  while(!(end[0] && __MTHREAD_SYNC(end2)))
    msgrcv(queue, 2, end);

  return 0;
}
