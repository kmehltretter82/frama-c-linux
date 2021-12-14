/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

import { json } from 'dome/data/json';

// --------------------------------------------------------------------------
// --- Frama-C Server Access (Client side)
// --------------------------------------------------------------------------

export interface Client {

  /** Server CLI */
  commandLine(sockaddr: string, params: string[]): string[];

  /** Connection */
  connect(addr: string): void;

  /** Disconnection */
  disconnect(): void;

  /** Send Request */
  send(kind: string, id: string, request: string, data: any): void;

  /** Signal ON */
  sigOn(id: string): void;

  /** Signal ON */
  sigOff(id: string): void;

  /** Kill Request */
  kill(id: string): void;

  /** Polling */
  poll(): void;

  /** Shutdown the server */
  shutdown(): void;

  /** Request data callback */
  onData(callback: (id: string, data: json) => void): void;

  /** Rejected request callback */
  onRejected(callback: (id: string, msg: string) => void): void;

  /** Killed request callback */
  onKilled(callback: (id: string) => void): void;

  /** Signal callback */
  onSignal(callback: (id: string) => void): void;

  /** Error callback */
  onError(callback: (msg: string) => void): void;

  /** Idle callback */
  onIdle(callback: () => void): void;

}

// --------------------------------------------------------------------------
