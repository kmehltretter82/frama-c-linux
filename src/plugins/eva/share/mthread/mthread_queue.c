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

#include "mthread_queue.h"


int queuecreate(framac_mthread_name q, int size) {
  *((int*) q) = __FRAMAC_QUEUE_INIT(q, size);
  return 0;
}

int msgsnd(framac_mthread_id msgqid, const char *mess, int size) {
  int result =__FRAMAC_MESSAGE_SEND(msgqid, mess, size);
  // TODO: position errno
  return result;
}

int msgrcv(framac_mthread_id msgqid, int size, char* mess) {
  return __FRAMAC_MESSAGE_RECEIVE(msgqid, size, mess);
}
