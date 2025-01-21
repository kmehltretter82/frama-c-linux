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

#ifndef __FC_DEFINE_AT
#define __FC_DEFINE_AT
#include "features.h"
__PUSH_FC_STDLIB
__BEGIN_DECLS

#define AT_FDCWD -100
#define AT_EACCESS 0x200
#define AT_SYMLINK_NOFOLLOW 0x100
#define AT_SYMLINK_FOLLOW 0x400
#define AT_REMOVEDIR 0x200

// Non-POSIX (GNU extensions)
#define AT_EMPTY_PATH 0x1000
#define AT_RECURSIVE 0x8000
#define AT_STATX_DONT_SYNC 0x4000
#define AT_STATX_FORCE_SYNC 0x2000
#define AT_STATX_SYNC_AS_STAT 0x0000
#define AT_STATX_SYNC_TYPE 0x6000

__END_DECLS

__POP_FC_STDLIB
#endif // __FC_DEFINE_AT
