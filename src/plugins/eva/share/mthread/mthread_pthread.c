/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

/* Stubs for analyzing programs using the POSIX threads library
   Redefining useful parts of pthread.h */

#include <mthread.h>
#include <pthread.h>

int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
                   void *(*start_routine)(void *), void *arg) {
  int result = Frama_C_thread_create(thread, start_routine, arg);
  if (result > 0) {
    *thread = result;
    Frama_C_thread_start(result);
    return 0;
  } else {
    return 11; /* EAGAIN */
  }
}

int pthread_cancel(pthread_t thread) {
  int result = Frama_C_thread_cancel(thread);
  return (result != -1 ? 0 : 3 /* ESRCH */);
}

pthread_t pthread_self(void) { return Frama_C_thread_id(); }

int pthread_mutex_init(pthread_mutex_t *restrict mutex,
                       const pthread_mutexattr_t *restrict attr) {
  int result = Frama_C_mutex_init(mutex);
  if (result > 0) {
    mutex->_fc = result;
    return 0;
  } else {
    return 22; /* EINVAL */
  }
}

int pthread_mutex_lock(pthread_mutex_t *mutex) {
  int result = Frama_C_mutex_lock(mutex->_fc);
  return (result != -1 ? 0 : 22 /* EINVAL */);
}

int pthread_mutex_trylock(pthread_mutex_t *mutex) {
  int result = Frama_C_mutex_lock(mutex->_fc);
  return (result != -1 ? 0 : 22 /* EINVAL */);
}

int pthread_mutex_unlock(pthread_mutex_t *mutex) {
  int result = Frama_C_mutex_unlock(mutex->_fc);
  return (result != -1 ? 0 : 22 /* EINVAL */);
}

/* ==========================================*/
/* Functions currently not perfectly stubbed */

// Does not store the return code
void pthread_exit(void *thread_return) { Frama_C_thread_exit(thread_return); }

extern volatile int NON_DET_JOIN;
// Overapproximated return code for the function and the joined threads
int pthread_join(pthread_t thread, void **thread_return) {
  if (thread_return != 0)
    *thread_return = NON_DET_JOIN;
  return NON_DET_JOIN ? -1 : 0;
}

// The mutex is unlocked then locked again, but the condvar is not supported
int pthread_cond_wait(pthread_cond_t *restrict cond,
                      pthread_mutex_t *restrict mutex) {
  int result;
  if (result = pthread_mutex_unlock(mutex))
    return result;
  // TODO: wait on cond atomically with the above unlock
  if (result = pthread_mutex_lock(mutex))
    return result;
  return 0;
}
int pthread_cond_timedwait(pthread_cond_t *restrict cond,
                           pthread_mutex_t *restrict mutex,
                           const struct timespec *restrict abstime) {
  int result;
  if (result = pthread_mutex_unlock(mutex))
    return result;
  // TODO: wait on cond until abstime atomically with the above unlock
  if (result = pthread_mutex_lock(mutex))
    return result;
  return 0;
}

/* ================================*/
/* Stubs that do nothing */

int pthread_detach(pthread_t thread) { return 0; }

int pthread_mutex_destroy(pthread_mutex_t *mutex) { return 0; }

int pthread_setcancelstate(int state, int *oldstate) { return 0; }
int pthread_setcanceltype(int type, int *oldtype) { return 0; }
void pthread_testcancel(void) {}

int pthread_cond_init(pthread_cond_t *restrict cond,
                      const pthread_condattr_t *restrict attr) {
  return 0;
}
int pthread_cond_signal(pthread_cond_t *cond) { return 0; }
int pthread_cond_destroy(pthread_cond_t *cond) { return 0; }
int pthread_cond_broadcast(pthread_cond_t *cond) { return 0; }
