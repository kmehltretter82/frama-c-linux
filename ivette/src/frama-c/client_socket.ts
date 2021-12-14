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

import Net from 'net';
import { Debug } from 'dome';
import Emitter from 'events';
import { json } from 'dome/data/json';
import { Client } from './client';

const D = new Debug('SocketServer');

// --------------------------------------------------------------------------
// --- Frama-C Server API
// --------------------------------------------------------------------------

class SocketClient implements Client {

  events = new Emitter();
  running = false;
  socket: Net.Socket | undefined;
  queue: json[] = [];
  buffer: Buffer = Buffer.from('');

  /** Connection */
  connect(sockaddr: string): void {
    if (this.socket) {
      this.socket.destroy();
    }
    this.socket = Net.createConnection(sockaddr, () => {
      D.log('Client connected');
      this.running = true;
      this._flush();
    });
    // Using Buffer data encoding at this level
    this.socket.on('end', () => this.disconnect());
    this.socket.on('data', (data: Buffer) => this._receive(data));
    this.socket.on('error', (err: Error) => {
      D.warn('Socket error', err);
    });
  }

  disconnect(): void {
    this.queue = [];
    if (this.socket) {
      D.log('Client disconnected');
      this.socket.destroy();
      this.socket = undefined;
    }
  }

  /** Send Request */
  send(kind: string, id: string, request: string, data: any): void {
    this.queue.push({ cmd: kind, id, request, data });
    this._flush();
  }

  /** Signal ON */
  sigOn(id: string): void {
    this.queue.push({ cmd: 'SIGON', id });
    this._flush();
  }

  /** Signal ON */
  sigOff(id: string): void {
    this.queue.push({ cmd: 'SIGOFF', id });
    this._flush();
  }

  /** Kill Request */
  kill(id: string): void {
    this.queue.push({ cmd: 'KILL', id });
    this._flush();
  }

  /** Polling */
  poll(): void {
    this.queue.push('POLL');
    this._flush();
  }

  /** Shutdown the server */
  shutdown(): void {
    this.queue.push('SHUTDOWN');
    this._flush();
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

  /** Signal callback */
  onIdle(callback: () => void): void {
    this.events.on('IDLE', callback);
  }

  // --------------------------------------------------------------------------
  // --- Low-Level Management
  // --------------------------------------------------------------------------

  _flush() {
    if (this.running) {
      this.queue.forEach((cmd) => {
        this._send(Buffer.from(JSON.stringify(cmd), 'utf8'));
      });
      this.queue = [];
    }
  }

  _send(data: Buffer) {
    const s = this.socket;
    if (s) {
      const len = data.length;
      const hex = Number(len).toString(16).toUpperCase();
      const padding = '0000000000000000';
      const header =
        len < 0xFFF ? 'S' + padding.substring(hex.length, 3) :
          len < 0xFFFFFFF ? 'L' + padding.substring(hex.length, 7) :
            'W' + padding.substring(hex.length, 15);
      s.write(Buffer.from(header + hex));
      s.write(data);
    }
  }

  _fetch(): undefined | string {
    const msg = this.buffer;
    const len = msg.length;
    this.buffer = msg;
    if (len < 1) return;
    const hd = msg.readInt8(0);
    // 'S': 83, 'L': 76, 'W': 87
    const nhex = hd == 83 ? 3 : hd == 76 ? 7 : 15;
    if (len < 1 + nhex) return;
    const size = Number.parseInt(msg.slice(1, nhex).toString('ascii'), 16);
    const offset = 1 + nhex + size;
    if (len < offset) return;
    this.buffer = msg.slice(offset);
    return msg.slice(1 + nhex, offset).toString('utf8');
  }

  _receive(chunk: Buffer) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (true) {
      const data = this._fetch();
      if (data === undefined) break;
      try {
        const cmd: any = JSON.parse(data);
        if (cmd !== null && typeof (cmd) === 'object') {
          switch (cmd.res) {
            case 'DATA': this.events.emit('DATA', cmd.id, cmd.data); break;
            case 'ERROR': this.events.emit('ERROR', cmd.msg); break;
            case 'KILLED': this.events.emit('KILLED', cmd.id); break;
            case 'REJECTED': this.events.emit('REJECT', cmd.id); break;
            case 'SIGNAL': this.events.emit('SIGNAL', cmd.id); break;
            default:
              D.warn('Unknown command', cmd);
          }
        } else
          D.warn('Misformed data', data);
      } catch (err) {
        D.warn('Misformed JSON', data, err);
      }
    }
  }

}

export const client: Client = new SocketClient();

// --------------------------------------------------------------------------
