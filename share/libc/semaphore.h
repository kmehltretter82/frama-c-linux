/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2024                                               */
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

// POSIX-compatible minimalist interface for sched.h

#ifndef __FC_SEMAPHORE
#define __FC_SEMAPHORE
#include "features.h"
__PUSH_FC_STDLIB
#include "time.h"

__BEGIN_DECLS

typedef union __fc_sem_t {
  char __size[16];
} sem_t;

#define SEM_FAILED ((sem_t *) 0)

/*@
  frees sem;
  assigns \result \from *sem;
*/
extern int sem_close(sem_t *sem);

/*@
  assigns \result, *sem \from *sem;
*/
extern int sem_destroy(sem_t *sem);

/*@
  assigns \result, *sval \from *sem;
*/
extern int sem_getvalue(sem_t *restrict sem, int *restrict sval);

/*@
  assigns \result, *sem \from *sem, pshared, value;
*/
extern int sem_init(sem_t *sem, int pshared, unsigned value);

/*@
  allocates \result;
  assigns \result \from indirect:name[0..], oflag; //missing: \from variadic args
*/
extern sem_t *sem_open(const char *name, int oflag, ...);

/*@
  assigns \result, *sem \from *sem;
*/
extern int sem_post(sem_t *sem);

/*@
  assigns \result, *sem \from *sem, *abstime;
*/
extern int sem_timedwait(sem_t *restrict sem,
                         const struct timespec *restrict abstime);

/*@
  assigns \result, *sem \from *sem;
*/
extern int sem_trywait(sem_t *sem);

/*@
  assigns \result \from indirect:name[0..]; //missing: assigns 'named semaphore'
*/
extern int sem_unlink(const char *name);

/*@
  assigns \result, *sem \from *sem;
*/
extern int sem_wait(sem_t *sem);

__END_DECLS
__POP_FC_STDLIB
#endif
