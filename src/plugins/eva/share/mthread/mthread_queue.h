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

#ifndef _FRAMAC_QUEUE_H_
#define _FRAMAC_QUEUE_H_

#include <mthread.h>

typedef int   msgqueue_t;

int queuecreate(framac_mthread_name q, int size);
int msgsnd(int msgqid, const char *mess, int size);
int msgrcv(int msgqid, int size, char* mess);

#endif
