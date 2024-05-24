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

#ifndef __FC_DLFCN_H
#define __FC_DLFCN_H
#include "features.h"
__PUSH_FC_STDLIB
#define RTLD_LAZY 1
#define RTLD_NOW 2
#define RTLD_GLOBAL 3
#define RTLD_LOCAL 4
__BEGIN_DECLS

/*@
  assigns \result \from indirect:file[0..], indirect:mode; //missing: from 'filesystem';
*/
extern void *dlopen(const char *file, int mode);

/*@
  assigns \result \from handle, indirect:name[0..]; //missing: from 'filesystem';
*/
extern void *dlsym(void *handle, const char *name);

/*@
  assigns \result \from indirect:handle; //missing: from 'filesystem';
*/
extern int dlclose(void *handle);

extern char __fc_dlerror[64];
char * const __fc_p_dlerror = __fc_dlerror;

/*@
  assigns \result \from __fc_p_dlerror; //missing: from 'filesystem';
*/
extern char *dlerror(void);

__END_DECLS
__POP_FC_STDLIB
#endif

