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

#include "mthread_interrupts.h"

framac_mthread_id __mutex_interrupts;

void __mthread_init_mutex_interrupt() {
  __mutex_interrupts = __FRAMAC_MUTEX_INIT("INTERRUPT");
}

int __FRAMAC_MTHREAD_LOCK_LEVEL = 0;

void __mthread_lock_interrupts() {
  if (__FRAMAC_MTHREAD_LOCK_LEVEL++)
    __FRAMAC_MTHREAD_SHOW("Overlock INTERRUPT");
  else
    __FRAMAC_MUTEX_LOCK(__mutex_interrupts);
}

void __mthread_unlock_interrupts() {
  if (--__FRAMAC_MTHREAD_LOCK_LEVEL)
    __FRAMAC_MTHREAD_SHOW("Decreasing INTERRUPT level");
  else
    __FRAMAC_MUTEX_UNLOCK(__mutex_interrupts);
}

void __mthread_interrupt(void (*f)(void *), void *arg) {
  while (1) {
    __mthread_lock_interrupts();
    (*f)(arg);
    __mthread_unlock_interrupts();
  }
}

void __mthread_void_interrupt(void (*f)(void)) {
  while (1) {
    __mthread_lock_interrupts();
    (*f)();
    __mthread_unlock_interrupts();
  }
}
