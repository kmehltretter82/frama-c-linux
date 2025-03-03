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

#ifndef __FC_MTHREAD
#define __FC_MTHREAD
#include "features.h"
__PUSH_FC_STDLIB

__BEGIN_DECLS

#ifndef MTHREAD_NUMBER_IDS
#define MTHREAD_NUMBER_IDS 32
#endif

__FC_EXTERN int __fc_mthread_shared;

int __fc_mthread_threads_running = 0;

int __fc_mthread_threads[MTHREAD_NUMBER_IDS];
int __fc_mthread_mutexes[MTHREAD_NUMBER_IDS];
int __fc_mthread_queues[MTHREAD_NUMBER_IDS];

typedef void *__fc_mthread_name;

typedef int __fc_mthread_id;

//@ assigns __fc_mthread_shared \from \nothing;
__fc_mthread_id Frama_C_thread_create(__fc_mthread_name, void *(*)(), ...)
    __attribute__((FC_BUILTIN));
//@ assigns __fc_mthread_shared \from \nothing;
int Frama_C_thread_start(__fc_mthread_id) __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
int Frama_C_thread_suspend(__fc_mthread_id) __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
int Frama_C_thread_cancel(__fc_mthread_id) __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
__fc_mthread_id Frama_C_thread_id(void) __attribute__((FC_BUILTIN));

/*@ terminates \false;
  @ assigns __fc_mthread_shared \from \nothing; */
void Frama_C_thread_exit(void *) __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
void Frama_C_thread_priority(int p) __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
__fc_mthread_id Frama_C_mutex_init(__fc_mthread_name)
    __attribute__((FC_BUILTIN));
//@ assigns __fc_mthread_shared \from \nothing;
int Frama_C_mutex_lock(__fc_mthread_id) __attribute__((FC_BUILTIN));
//@ assigns __fc_mthread_shared \from \nothing;
int Frama_C_mutex_unlock(__fc_mthread_id) __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
__fc_mthread_id Frama_C_queue_init(__fc_mthread_name, int)
    __attribute__((FC_BUILTIN));

/*@ requires \valid_read(buf+(0..(size-1)));
  @ assigns __fc_mthread_shared \from \nothing; */
int Frama_C_queue_send(__fc_mthread_id id, const char *buf, int size)
    __attribute__((FC_BUILTIN));

/*@ requires \valid(buf+(0..(size-1)));
  @ assigns *buf \from \empty;
  @ assigns __fc_mthread_shared \from \nothing; */
int Frama_C_queue_receive(__fc_mthread_id, int size, char *buf)
    __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
void Frama_C_mthread_show(char const *, ...) __attribute__((FC_BUILTIN));
//@ assigns __fc_mthread_shared \from \nothing;
void Frama_C_mthread_name_thread(__fc_mthread_id, __fc_mthread_name)
    __attribute__((FC_BUILTIN));
//@ assigns __fc_mthread_shared \from \nothing;
void Frama_C_mthread_name_mutex(__fc_mthread_id, __fc_mthread_name)
    __attribute__((FC_BUILTIN));
//@ assigns __fc_mthread_shared \from \nothing;
void Frama_C_mthread_name_queue(__fc_mthread_id, __fc_mthread_name)
    __attribute__((FC_BUILTIN));

//@ assigns __fc_mthread_shared \from \nothing;
void Frama_C_mthread_sync(void) __attribute__((FC_BUILTIN));

#define __MTHREAD_SYNC(v) (Frama_C_mthread_sync(), (v))

__END_DECLS

__POP_FC_STDLIB
#endif // __FC_MTHREAD
