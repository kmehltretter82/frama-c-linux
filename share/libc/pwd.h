/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2019                                               */
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

#ifndef __FC_PWD_H__
#define __FC_PWD_H__
#include "features.h"
__PUSH_FC_STDLIB

#include "__fc_define_uid_and_gid.h"

// for size_t
#include "stddef.h"

__BEGIN_DECLS

struct passwd {
  char    *pw_name;
  char    *pw_passwd; // not POSIX, but allowed by it, and present in glibc
  uid_t    pw_uid;
  gid_t    pw_gid;
  char    *pw_dir;
  char    *pw_shell;
};

extern char __fc_getpwuid_pw_name[64];
extern char __fc_getpwuid_pw_passwd[64];
extern uid_t __fc_getpwuid_pw_uid;
extern gid_t __fc_getpwuid_pw_gid;
extern char __fc_getpwuid_pw_dir[64];
extern char __fc_getpwuid_pw_shell[64];

struct passwd __fc_getpwuid =
  {.pw_name = __fc_getpwuid_pw_name,
   .pw_passwd = __fc_getpwuid_pw_passwd,
   .pw_uid = __fc_getpwuid_pw_uid,
   .pw_gid = __fc_getpwuid_pw_gid,
   .pw_dir = __fc_getpwuid_pw_dir,
   .pw_shell = __fc_getpwuid_pw_shell};

struct passwd *__fc_p_getpwuid = & __fc_getpwuid;


extern struct passwd *getpwnam(const char *);

/*@ // missing: assigns \result, __fc_getpwuid[0..] \from 'password database'
  assigns \result \from __fc_p_getpwuid, indirect:uid;
  assigns __fc_getpwuid \from indirect:uid;
  ensures result_null_or_internal_struct:
    \result == \null || \result == __fc_p_getpwuid;
*/
extern struct passwd *getpwuid(uid_t uid);


extern int            getpwnam_r(const char *, struct passwd *, char *,
			  size_t, struct passwd **);
extern int            getpwuid_r(uid_t, struct passwd *, char *,
			  size_t, struct passwd **);
extern void           endpwent(void);
extern struct passwd *getpwent(void);
extern void           setpwent(void);

__END_DECLS

__POP_FC_STDLIB
#endif
