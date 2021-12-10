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

import Emitter from 'events';
import { Request as ZmqRequest } from 'zeromq';
import { json } from 'dome/data/json';
import { Client } from './client';

const pollingTimeout = 50;

// --------------------------------------------------------------------------
// --- Frama-C Server API
// --------------------------------------------------------------------------

class ZmqClient implements Client {

  constructor() { }

  events = new Emitter();

  queueCmd: string[] = [];
  queueId: string[] = [];
  zmqSocket: ZmqRequest | undefined;
  zmqIsBusy = false;

  /** Connection */
  connect(sockaddr: string): void {
    if (!this.zmqSocket) {
      this.zmqSocket.close();
    }
    this.zmqSocket = new ZmqRequest();
    this.zmqIsBusy = false;
    this.zmqSocket.connect(sockaddr);
  }

  disconnect(): void {
    this.zmqIsBusy = false;
    this.queueCmd = [];
    this.queueId = [];
    if (this.zmqSocket) {
      this.zmqSocket.close();
      this.zmqSocket = undefined;
    }
  }

  /** Send Request */
  send(kind: string, id: string, request: string, data: any): void {
    this.queueCmd.push(kind, id, request, data);
    this.queueId.push(id);
    this._flush();
  }

  /** Signal ON */
  sigOn(id: string): void { this.queueCmd.push('SIGON', id); this._flush(); }

  /** Signal ON */
  sigOff(id: string): void { this.queueCmd.push('SIGOFF', id); this._flush(); }

  /** Kill Request */
  kill(id: string): void {
    if (this.zmqSocket) {
      this.queueCmd.push('KILL', id);
      this._flush();
    }
  }

  /** Polling */
  poll(): void { }

  /** Shutdown the server */
  shutdown(): void {
    this._reset();
    this._flush();
    this.queueCmd.push('SHUTDOWN');
  }

  /** Request data callback */
  onData(callback: (id: string, data: json) => void): void {
    this.events.on('DATA', callback);
  }

  /** Rejected request callback */
  onRejected(callback: (id: string, err: string) => void): void {
    this.events.on('REJECT', callback);
  }

  /** Request error callback */
  onError(callback: (msg: string) => void): void {
    this.events.on('ERROR', callback);
  }

  /** Killed request callback */
  onKilled(callback: (id: string) => void): void {
    this.events.on('KILL', callback);
  }

  /** Signal callback */
  onSignal(callback: (id: string) => void): void {
    this.events.on('SIGNAL', callback);
  }

  /** Idle callback */
  onIdle(callback: () => void): void {
    this.events.on('CALLBACK', callback);
  }

  // --------------------------------------------------------------------------
  // --- Low-Level Management
  // --------------------------------------------------------------------------

  pollingTimer: NodeJS.Timeout | undefined;
  flushingTimer: NodeJS.Immediate | undefined;

  _reset() {
    if (this.flushingTimer) {
      clearImmediate(this.flushingTimer);
      this.flushingTimer = undefined;
    }
    if (this.pollingTimer) {
      clearTimeout(this.pollingTimer);
      this.pollingTimer = undefined;
    }
  }

  _flush() {
    if (!this.flushingTimer) {
      this.flushingTimer = setImmediate(() => {
        this.flushingTimer = undefined;
        this._send();
      });
    }
  }

  _poll() {
    if (!this.pollingTimer) {
      this.pollingTimer = setTimeout(() => {
        this.pollingTimer = undefined;
        this._send();
      }, pollingTimeout);
    }
  }

  async _send() {
    // when busy, will be eventually re-triggered
    if (!this.zmqIsBusy) {
      const cmds = this.queueCmd;
      if (!cmds.length) {
        this.queueCmd.push('POLL');
        this.events.emit('IDLE');
      }
      this.zmqIsBusy = true;
      const ids = this.queueId;
      this.queueCmd = [];
      this.queueId = [];
      try {
        await this.zmqSocket?.send(cmds);
        const resp = await this.zmqSocket?.receive();
        this._receive(resp);
      } catch (error) {
        this._error(`Error in send/receive on ZMQ socket. ${error.toString()}`);
        const err = 'Canceled request';
        ids.forEach((rid) => this._reject(rid, err));
      }
      this.zmqIsBusy = false;
      this.events.emit('IDLE');
    }
  }

  _data(id: string, data: any) {
    this.events.emit('DATA', id, data);
  }

  _reject(id: string, error: string) {
    this.events.emit('REJECT', id, error);
  }

  _signal(id: string) {
    this.events.emit('SIGNAL', id);
  }

  _error(err: any) {
    this.events.emit('ERROR', err);
  }

  _receive(resp: any) {
    try {
      let rid;
      let data;
      let err;
      let cmd;
      const shift = () => resp.shift().toString();
      let unknownResponse = false;
      while (resp.length && !unknownResponse) {
        cmd = shift();
        switch (cmd) {
          case 'NONE':
            break;
          case 'DATA':
            rid = shift();
            data = shift();
            this._data(rid, data);
            break;
          case 'KILLED':
            rid = shift();
            this._reject(rid, 'Killed');
            break;
          case 'ERROR':
            rid = shift();
            err = shift();
            this._reject(rid, err);
            break;
          case 'REJECTED':
            rid = shift();
            this._reject(rid, 'Rejected');
            break;
          case 'SIGNAL':
            rid = shift();
            this._signal(rid);
            break;
          case 'WRONG':
            err = shift();
            this._error(`ZMQ Protocol Error: ${err}`);
            break;
          default:
            this._error(`Unknown Response: ${cmd}`);
            unknownResponse = true;
            break;
        }
      }
    } finally {
      if (this.queueCmd.length) this._flush();
      else this._poll();
    }
  }

}

export const client: Client = new ZmqClient();

// --------------------------------------------------------------------------
