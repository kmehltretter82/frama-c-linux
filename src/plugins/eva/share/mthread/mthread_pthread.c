/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2025                                               */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  you can redistribute it and/or modify it under the terms of the GNU   */
/*  Lesser General Public License as published by the Free Software       */
/*  Foundation, version 2.1.                                              */
/*                                                                        */
/*  It is distributed in the hope that it will be useful,                 */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*  GNU Lesser General Public License for more details.                   */
/*                                                                        */
/*  See the GNU Lesser General Public License version 2.1                 */
/*  for more details (enclosed in the file licenses/LGPLv2.1).            */
/*                                                                        */
/**************************************************************************/

#include "mthread_pthread.h"

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
    *mutex = result;
    return 0;
  } else {
    return 22; /* EINVAL */
  }
}

int pthread_mutex_lock(pthread_mutex_t *mutex) {
  int result = Frama_C_mutex_lock(*mutex);
  return (result != -1 ? 0 : 22 /* EINVAL */);
}

int pthread_mutex_trylock(pthread_mutex_t *mutex) {
  int result = Frama_C_mutex_lock(*mutex);
  return (result != -1 ? 0 : 22 /* EINVAL */);
}

int pthread_mutex_unlock(pthread_mutex_t *mutex) {
  int result = Frama_C_mutex_unlock(*mutex);
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

/* ================================*/
/* Stubs that do nothing */

int pthread_setcancelstate(int state, int *oldstate) { return 0; }

int pthread_setcanceltype(int type, int *oldtype) { return 0; }

void pthread_testcancel(void) {}
