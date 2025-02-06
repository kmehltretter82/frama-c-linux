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

#include "signal.h"
#include "errno.h"
__PUSH_FC_STDLIB

struct sigaction __fc_sigaction[SIGRTMAX+1];

__fc_sighandler_t __fc_signal_handlers[SIGRTMAX+1];

void __fc_sig_dfl(int sig) {}
void __fc_sig_ign(int sig) {}
void __fc_sig_err(int sig) {}

__fc_sighandler_t signal(int sig, __fc_sighandler_t func) {
  static volatile int nondet;
  if (nondet && sig >= 0 && sig <= SIGRTMAX && func != NULL) {
    __fc_sighandler_t old = __fc_signal_handlers[sig];
    __fc_signal_handlers[sig] = func;

    // If __fc_signal_handlers[sig] was not already set, choose between
    // SIG_DFL and SIG_IGN now
    if (old) {
      return old;
    } else if (nondet) {
      return SIG_DFL;
    } else {
      return SIG_IGN;
    }
  } else {
    errno = EINVAL;
    return SIG_ERR;
  }
}

__POP_FC_STDLIB
