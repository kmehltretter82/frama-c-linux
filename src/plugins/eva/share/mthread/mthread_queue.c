/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2025                                               */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  All rights reserved.                                                  */
/*  Contact CEA LIST for licensing.                                       */
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
