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

#ifndef __FRAMAC_MTHREAD
#define __FRAMAC_MTHREAD

#ifndef MTHREAD_NUMBER_IDS
  #define MTHREAD_NUMBER_IDS 32
#endif

extern int __FRAMAC_MTHREAD_SHARED;

int __FRAMAC_MTHREAD_THREADS_RUNNING=0;

int __FRAMAC_MTHREAD_THREADS[MTHREAD_NUMBER_IDS];
int __FRAMAC_MTHREAD_MUTEXES[MTHREAD_NUMBER_IDS];
int __FRAMAC_MTHREAD_QUEUES[MTHREAD_NUMBER_IDS];

typedef void* framac_mthread_name;

typedef int framac_mthread_id;

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
framac_mthread_id __FRAMAC_THREAD_CREATE(framac_mthread_name, void *(*)(), ...);
//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
int __FRAMAC_THREAD_START(framac_mthread_id);

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
int __FRAMAC_THREAD_SUSPEND(framac_mthread_id);

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
int __FRAMAC_THREAD_CANCEL(framac_mthread_id);

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
framac_mthread_id __FRAMAC_THREAD_ID(void);

/*@ terminates \false;
  @ assigns __FRAMAC_MTHREAD_SHARED \from \nothing; */
void __FRAMAC_THREAD_EXIT(void *);

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
void __FRAMAC_THREAD_PRIORITY(int p);

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
framac_mthread_id __FRAMAC_MUTEX_INIT(framac_mthread_name);
//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
int __FRAMAC_MUTEX_LOCK(framac_mthread_id);
//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
int __FRAMAC_MUTEX_UNLOCK(framac_mthread_id);


//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
framac_mthread_id __FRAMAC_QUEUE_INIT(framac_mthread_name, int);

/*@ requires \valid_read(buf+(0..(size-1)));
  @ assigns __FRAMAC_MTHREAD_SHARED \from \nothing; */
int __FRAMAC_MESSAGE_SEND(framac_mthread_id id, const char* buf, int size);

/*@ requires \valid(buf+(0..(size-1)));
  @ assigns *buf \from \empty;
  @ assigns __FRAMAC_MTHREAD_SHARED \from \nothing; */
int __FRAMAC_MESSAGE_RECEIVE(framac_mthread_id, int size, char* buf);


//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
void __FRAMAC_MTHREAD_SHOW(char const*, ...);
//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
void __FRAMAC_MTHREAD_NAME_THREAD(framac_mthread_id, framac_mthread_name);
//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
void __FRAMAC_MTHREAD_NAME_MUTEX(framac_mthread_id, framac_mthread_name);
//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
void __FRAMAC_MTHREAD_NAME_QUEUE(framac_mthread_id, framac_mthread_name);

//@ assigns __FRAMAC_MTHREAD_SHARED \from \nothing;
void __FRAMAC_MTHREAD_SYNC(void);


#define __MTHREAD_SYNC(v) (__FRAMAC_MTHREAD_SYNC(), (v))

#endif
