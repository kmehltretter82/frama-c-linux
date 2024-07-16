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

/* Non-POSIX; glibc definitions */

#ifndef __FC_ERROR_H
#define __FC_ERROR_H
#include "features.h"
__PUSH_FC_STDLIB
#include "__fc_machdep.h"

__BEGIN_DECLS

extern unsigned int error_message_count;

extern int error_one_per_line;

/*@
  assigns error_message_count \from error_message_count;
*/
extern void error(int __status, int __errnum, const char *__format, ...);

/*@
  assigns error_message_count \from error_message_count;
*/
extern void error_at_line(int __status, int __errnum, const char *__fname,
                          unsigned int __lineno, const char *__format, ...);

extern void (*error_print_progname)(void);

__END_DECLS

__POP_FC_STDLIB
#endif
