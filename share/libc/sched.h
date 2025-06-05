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

#ifndef __FC_SCHED_H
#define __FC_SCHED_H
#include "features.h"
__PUSH_FC_STDLIB

#include "__fc_define_timespec.h"
#include "__fc_define_pid_t.h"
#include "errno.h"

__BEGIN_DECLS

struct sched_param {
  int sched_priority;
};

#define SCHED_OTHER             0
#define SCHED_FIFO              1
#define SCHED_RR                2
#define SCHED_SPORADIC          6

/*@
  assigns \result \from policy;
  assigns errno \from indirect:policy;
*/
extern int sched_get_priority_max(int policy);

/*@
  assigns \result \from policy;
  assigns errno \from indirect:policy;
*/
extern int sched_get_priority_min(int policy);

/*@
  assigns \result, *param \from pid; //missing: \from 'process parameters';
  assigns errno \from indirect:pid; //missing: \from 'process parameters';
*/
extern int sched_getparam(pid_t pid, struct sched_param *param);

/*@
  assigns \result \from pid; //missing: \from 'process parameters';
  assigns errno \from indirect:pid; //missing: \from 'process parameters';
*/
extern int sched_getscheduler(pid_t pid);

/*@
  assigns \result, *interval \from indirect:pid;
    //missing: \from 'process parameters';
  assigns errno \from indirect:pid; //missing: \from 'pid table';
*/
extern int sched_rr_get_interval(pid_t pid, struct timespec *interval);

/*@
  assigns \result \from pid, *param; //missing: assigns 'process parameters';
  assigns errno \from indirect:pid; //missing: \from 'process parameters';
*/
extern int sched_setparam(pid_t pid, const struct sched_param *param);

/*@
  assigns \result \from indirect:pid, indirect:policy, indirect:*param;
    //missing: assigns 'process parameters',
    //         and '\from previous scheduling policy';
  assigns errno \from indirect:pid, indirect:policy, indirect:*param;
    //missing: from 'process parameters';
*/
extern int sched_setscheduler(pid_t pid, int policy,
                              const struct sched_param *param);

/*@
  assigns \result \from \nothing; //missing: \from 'thread status'
*/
extern int sched_yield(void);

__END_DECLS
__POP_FC_STDLIB
#endif
