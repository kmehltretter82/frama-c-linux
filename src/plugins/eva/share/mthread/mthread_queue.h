/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier LGPL-2.1                                      */
/*  Copyright (C)                                                         */
/*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  */
/*                                                                        */
/**************************************************************************/

#ifndef _FRAMAC_QUEUE_H_
#define _FRAMAC_QUEUE_H_

#include <mthread.h>

typedef int msgqueue_t;

int queuecreate(__fc_mthread_name q, int size);
int msgsnd(int msgqid, const char *mess, int size);
int msgrcv(int msgqid, int size, char *mess);

#endif
