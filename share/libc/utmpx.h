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

#ifndef __FC_UTMPX
#define __FC_UTMPX
#include "features.h"
__PUSH_FC_STDLIB

#include "__fc_define_pid_t.h"
#include "__fc_utmp_constants.h"
#include "stdint.h"
#include "sys/time.h"

__BEGIN_DECLS

// The sizes of arrays and values for the constants below are based on those
// of the glibc, declared in the order given by POSIX.1-2008.

struct utmpx {
  char ut_user[32];
  char ut_id[4];
  char ut_line[32];
  char ut_host[256]; // not POSIX, but allowed by it, and present in glibc
  pid_t ut_pid;
  short ut_type;
  struct timeval ut_tv;
  int32_t ut_addr_v6[4]; // not POSIX, but allowed by it
  char __glibc_reserved[20]; // not POSIX, but allowed by it
};

// static storage used by some getter functions
extern struct utmpx __fc_getx;

/*@
  assigns \result \from &__fc_getx, indirect:__fc_utmp;
  assigns __fc_getx \from __fc_getx, indirect:__fc_utmp;
*/
extern struct utmpx *getutxent (void);

/*@
  assigns __fc_utmp \from __fc_utmp;
*/
extern void setutxent (void);

/*@
  assigns __fc_utmp \from __fc_utmp;
*/
extern void endutxent (void);

/*@
  assigns \result \from &__fc_getx, indirect:__fc_utmp, indirect:*id;
  assigns __fc_getx \from __fc_getx, indirect:__fc_utmp, indirect:*id;
*/
extern struct utmpx *getutxid (const struct utmpx *id);

/*@
  assigns \result \from &__fc_getx, indirect:__fc_utmp, indirect:*line;
  assigns __fc_getx \from __fc_getx, indirect:__fc_utmp, indirect:*line;
*/
extern struct utmpx *getutxline (const struct utmpx *line);

/*@
  assigns __fc_utmp \from __fc_utmp, *utmp_ptr;
  assigns \result \from utmp_ptr;
*/
extern struct utmpx *pututxline (const struct utmpx *utmp_ptr);

__END_DECLS
__POP_FC_STDLIB
#endif
