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

#ifndef __FC_DEFINE_FC_UTMP_CONSTANTS
#define __FC_DEFINE_FC_UTMP_CONSTANTS
#include "features.h"
__PUSH_FC_STDLIB
__BEGIN_DECLS
#include "stdio.h"

#define _PATH_UTMP "/var/run/utmp"
#define UTMP_FILE     _PATH_UTMP
#define UTMP_FILENAME _PATH_UTMP
#define _PATH_WTMP "/var/log/wtmp"
#define WTMP_FILE     _PATH_WTMP
#define WTMP_FILENAME _PATH_WTMP

#define UT_LINESIZE  32
#define UT_NAMESIZE  32
#define UT_HOSTSIZE  256

#define EMPTY 0
#define BOOT_TIME 2
#define OLD_TIME 4
#define NEW_TIME 3
#define USER_PROCESS 7
#define INIT_PROCESS 5
#define LOGIN_PROCESS 6
#define DEAD_PROCESS 8

#define ut_name ut_user
#ifndef _NO_UT_TIME
# define ut_time ut_tv.tv_sec
#endif
#define ut_xtime ut_tv.tv_sec
#define ut_addr ut_addr_v6[0]

// represents the user accounting database, /var/run/utmp
extern FILE __fc_utmp;

// represents the user accounting database, /var/run/wtmp
extern FILE __fc_wtmp;

__END_DECLS
__POP_FC_STDLIB
#endif
