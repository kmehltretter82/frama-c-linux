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

/* Stubs for analyzing programs using the POSIX threads library
   Redefining useful parts of pthread.h */

#ifndef _FRAMAC_PTHREAD_H_
#define _FRAMAC_PTHREAD_H_

#include <mthread.h>

typedef __fc_mthread_id pthread_t;
typedef __fc_mthread_id pthread_attr_t;
typedef __fc_mthread_id pthread_mutex_t;
typedef __fc_mthread_id pthread_mutexattr_t;

#define PTHREAD_MUTEX_INITIALIZER 1

int pthread_create(pthread_t *thread, const pthread_attr_t *attr,
                   void *(*start_routine)(void *), void *arg);
int pthread_cancel(pthread_t thread);
int pthread_join(pthread_t thread, void **thread_return);
void pthread_exit(void *thread_return) __attribute__((noreturn));
pthread_t pthread_self(void);

int pthread_mutex_init(pthread_mutex_t *restrict mutex,
                       const pthread_mutexattr_t *restrict attr);
int pthread_mutex_lock(pthread_mutex_t *mutex);
int pthread_mutex_unlock(pthread_mutex_t *mutex);

int pthread_setcancelstate(int state, int *oldstate);
int pthread_setcanceltype(int type, int *oldtype);
void pthread_testcancel(void);

#endif
