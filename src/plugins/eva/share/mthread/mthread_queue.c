/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

#include "mthread_queue.h"

int queuecreate(__fc_mthread_name q, int size) {
  *((int *)q) = Frama_C_queue_init(q, size);
  return 0;
}

int msgsnd(__fc_mthread_id msgqid, const char *mess, int size) {
  int result = Frama_C_queue_send(msgqid, mess, size);
  // TODO: position errno
  return result;
}

int msgrcv(__fc_mthread_id msgqid, int size, char *mess) {
  return Frama_C_queue_receive(msgqid, size, mess);
}
