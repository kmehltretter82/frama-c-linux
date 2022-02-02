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

// --------------------------------------------------------------------------
// --- Connection to Frama-C Server
// --------------------------------------------------------------------------

/**
   Manage the current Frama-C server/client interface
   @packageDocumentation
   @module frama-c/server
*/

import { debounce } from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as System from 'dome/system';
import * as Json from 'dome/data/json';
import { RichTextBuffer } from 'dome/text/buffers';
import { ChildProcess } from 'child_process';
import { client } from './client_socket';
//import { client } from './client_zmq';

// --------------------------------------------------------------------------
// --- Events
// --------------------------------------------------------------------------

/**
 *  Server Status Notification Event.

 *  This event is emitted whenever the server status changes.
 */
const STATUS = new Dome.Event<Status>('frama-c.server.status');

/**
 *  Server is actually started and running.

 *  This event is emitted when ther server _enters_ the `ON` state.
 *  The server is now ready to handle requests.
 */
const READY = new Dome.Event('frama-c.server.ready');

/**
 *  Server Status Notification Event

 *  This event is emitted when ther server _leaves_ the `ON` state.
 *  The server is no more able to handle requests until restart.
 */
const SHUTDOWN = new Dome.Event('frama-c.server.shutdown');

/**
 *  Server Signal event constructor.

 *  Event `frama-c.server.signal.<id>'` for signal `<id>`.
 */
export class SIGNAL extends Dome.Event {
  constructor(signal: string) {
    super(`frama-c.server.signal.${signal}`);
  }
}

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/** Server stages. */
export enum Status {
  /** Server is off. */
  OFF = 'OFF',
  /** Server is starting, but not on yet. */
  STARTING = 'STARTING',
  /** Server is on. */
  ON = 'ON',
  /** Server is halting, but not off yet. */
  HALTING = 'HALTING',
  /** Server is restarting. */
  RESTARTING = 'RESTARTING',
  /** Server is off upon failure. */
  FAILURE = 'FAILURE',
}

// --------------------------------------------------------------------------
// --- Server Global State
// --------------------------------------------------------------------------

/** The current server status. */
let status: Status = Status.OFF;

/** Request counter. */
let rqCount = 0;

/** Pending Requests. */
interface PendingRequest {
  resolve: (data: Json.json) => void;
  reject: (err?: string) => void;
}
const pending = new Map<string, PendingRequest>();

/** Server process. */
let process: ChildProcess | undefined;

/** Polling timeout when server is busy. */
const pollingTimeout = 200;
let pollingTimer: NodeJS.Timeout | undefined;

/** Killing timeout and timer for server process hard kill. */
const killingTimeout = 500;
let killingTimer: NodeJS.Timeout | undefined;

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

/** The server console buffer. */
export const buffer = new RichTextBuffer({ maxlines: 200 });

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/**
 *  Current server status.
 *  @return {Status} The current server status.
 */
export function getStatus(): Status { return status; }

/**
 *  Hook on current server (Custom React Hook).
 *  @return {Status} The current server status.
 */
export function useStatus(): Status {
  Dome.useUpdate(STATUS);
  return status;
}

/**
 *  Whether the server is running and ready to handle requests.
 *  @return {boolean} Whether server stage is [[ON]].
 */
export function isRunning(): boolean { return status === Status.ON; }

/**
 *  Number of requests still pending.
 *  @return {number} Pending requests.
 */
export function getPending(): number {
  return pending.size;
}

/**
 *  Register callback on `READY` event.
 *  @param {function} callback Invoked when the server enters [[ON]] stage.
 */
export function onReady(callback: () => void) { READY.on(callback); }

/**
 *  Register callback on `SHUTDOWN` event.
 *  @param {function} callback Invoked when the server leaves [[ON]] stage.
 */
export function onShutdown(callback: () => void) { SHUTDOWN.on(callback); }

// --------------------------------------------------------------------------
// --- Status Update
// --------------------------------------------------------------------------

function _status(newStatus: Status) {
  if (newStatus !== status) {
    const oldStatus = status;
    status = newStatus;
    STATUS.emit(newStatus);
    if (oldStatus === Status.ON) SHUTDOWN.emit();
    if (newStatus === Status.ON) READY.emit();
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Start)
// --------------------------------------------------------------------------

/**
 *  Start the server.
 *
 *  - If the server is either started or running, this is a no-op.
 *  - If the server is halting, it will restart.
 *  - Otherwise, the Frama-C server is spawned.
 */
export async function start() {
  switch (status) {
    case Status.OFF:
    case Status.FAILURE:
    case Status.RESTARTING:
      _status(Status.STARTING);
      try {
        await _launch();
      } catch (error) {
        buffer.log('[frama-c]', error);
        _exit(false);
      }
      return;
    case Status.HALTING:
      _status(Status.RESTARTING);
      return;
    default:
      return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Stop)
// --------------------------------------------------------------------------

/**
 *  Stop the server.
 *
 *  - If the server is starting, it is hard killed.
 *  - If the server is running, it is shutdown gracefully.
 *  - Otherwise, this is a no-op.
 */
export function stop() {
  switch (status) {
    case Status.STARTING:
      _status(Status.HALTING);
      _kill();
      return;
    case Status.ON:
      _status(Status.HALTING);
      _shutdown();
      return;
    default:
      return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Kill)
// --------------------------------------------------------------------------

/**
 *  Terminate the server.
 *
 *  - If the server is either starting, running or shutting down,
 *  it is hard killed and restart is canceled.
 *  - Otherwise, this is a no-op.
 */
export function kill() {
  switch (status) {
    case Status.STARTING:
    case Status.ON:
    case Status.HALTING:
    case Status.RESTARTING:
      _status(Status.HALTING);
      _kill();
      return;
    default:
      return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Restart)
// --------------------------------------------------------------------------

/**
 *  Restart the server.
 *
 *  - If the server is either off or paused on failure, simply start the server.
 *  - If the server is running, try to gracefully shutdown the server,
 *  and finally schedule a reboot on exit.
 *  - Otherwise, this is a no-op.
 */
export function restart() {
  switch (status) {
    case Status.OFF:
    case Status.FAILURE:
      start();
      return;
    case Status.ON:
      _status(Status.RESTARTING);
      _shutdown();
      return;
    case Status.HALTING:
      _status(Status.RESTARTING);
      return;
    default:
      return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Reset)
// --------------------------------------------------------------------------

/**
 *  Acknowledge the [[OFF]] or [[FAILURE]] stages.
 *
 *  - If the server is either off or paused on failure,
 *  clear the console and set server stage to [[OFF]].
 *  - Otherwise, this is a no-op.
 */
export function clear() {
  switch (status) {
    case Status.FAILURE:
    case Status.OFF:
      buffer.clear();
      _clear();
      _status(Status.OFF);
      return;
    default:
      return;
  }
}

// --------------------------------------------------------------------------
// --- Server Configure
// --------------------------------------------------------------------------

/** Server configuration. */
export interface Configuration {
  /** Process environment variables (default: `undefined`). */
  env?: any;
  /** Working directory (default: current). */
  cwd?: string;
  /** Server command (default: `frama-c`). */
  command?: string;
  /** Additional server arguments (default: empty). */
  params: string[];
  /** Server socket (default: `ipc:///tmp/ivette.frama-c.<pid>.io`). */
  sockaddr?: string;
  /** Shutdown timeout before server is hard killed, in milliseconds
   *  (default: 300ms). */
  timeout?: number;
  /** Server polling period in milliseconds (default: 200ms). */
  polling?: number;
  /** Process stdout log file (default: `undefined`). */
  logout?: string;
  /** Process stderr log file (default: `undefined`). */
  logerr?: string;
}

/** Server current configuration. */
let config: Configuration = { command: 'frama-c', params: [] };

/**
 *  Set the current server configuration.
 *  @param {Configuration} sc Server configuration.
 */
export function setConfig(sc: Configuration) {
  config = { ...sc };
}

/**
 *  Get the current server configuration.
 *  @return {Configuration} Current server configuration.
 */
export function getConfig(): Configuration {
  return config;
}

// --------------------------------------------------------------------------
// --- Low-level Launching
// --------------------------------------------------------------------------

async function _launch() {
  let {
    env,
    cwd,
    command = 'frama-c',
    params,
    sockaddr,
    logout,
    logerr,
  } = config;

  buffer.clear();
  buffer.append('$', command);
  const size = params.reduce((n, p) => n + p.length, 0);
  if (size < 40) {
    buffer.append('', ...params);
  } else {
    params.forEach((argv: string) => {
      if (argv.startsWith('-') || argv.endsWith('.c')
        || argv.endsWith('.i') || argv.endsWith('.h')) {
        buffer.append('\n    ');
      }
      buffer.append(' ');
      buffer.append(argv);
    });
  }
  buffer.append('\n');

  if (!sockaddr) {
    const tmp = Dome.getTempDir();
    const pid = Dome.getPID();
    sockaddr = System.join(tmp, `ivette.frama-c.${pid}.io`);
  }
  if (!cwd) cwd = System.getWorkingDir();
  logout = logout && System.join(cwd, logout);
  logerr = logerr && System.join(cwd, logerr);
  params = client.commandLine(sockaddr, params);
  const options = {
    cwd,
    stdout: { path: logout, pipe: true },
    stderr: { path: logerr, pipe: true },
    env,
  };
  // Launch Process
  process = await System.spawn(command, params, options);
  const logger = (text: string | string[]) => {
    buffer.append(text);
    if (text.indexOf('\n') >= 0) {
      buffer.scroll();
    }
  };
  process?.stdout?.on('data', logger);
  process?.stderr?.on('data', logger);
  process?.on('exit', (code: number | null, signal: string | null) => {
    if (signal) {
      // [signal] is non-null.
      buffer.log('[frama-c]', signal);
      _exit(false);
      return;
    }
    // [signal] is null, hence [code] is non-null (cf. NodeJS doc).
    if (code) {
      buffer.log('[frama-c] exit', code);
      _exit(false);
    } else {
      // [code] is zero: normal exit w/o error.
      _exit(true);
    }
  });
  // Connect to Server
  client.connect(sockaddr);
}

// --------------------------------------------------------------------------
// --- Low-level Killing
// --------------------------------------------------------------------------

function _clear() {
  rqCount = 0;
  pending.forEach((p: PendingRequest) => p.reject());
  pending.clear();
  if (pollingTimer) {
    clearTimeout(pollingTimer);
    pollingTimer = undefined;
  }
  if (killingTimer) {
    clearTimeout(killingTimer);
    killingTimer = undefined;
  }
}

function _kill() {
  client.disconnect();
  if (process) process.kill();
}

async function _shutdown() {
  _clear();
  client.shutdown();
  const killingPromise = new Promise((resolve) => {
    if (!killingTimer) {
      if (process) {
        const timeout = (config && config.timeout) || killingTimeout;
        killingTimer =
          setTimeout(() => {
            resolve(process?.kill());
          }, timeout);
      }
    }
  });
  await killingPromise;
}

function _exit(error: boolean) {
  _clear();
  client.disconnect();
  process = undefined;
  if (status === Status.RESTARTING) {
    setImmediate(start);
  }
  _status(error ? Status.FAILURE : Status.OFF);
}

// --------------------------------------------------------------------------
// --- Signal Management
// --------------------------------------------------------------------------

class SignalHandler {
  id: string;
  event: Dome.Event;
  active: boolean;
  listen: boolean;
  handler: _.DebouncedFunc<() => void>;

  constructor(id: string) {
    this.id = id;
    this.event = new SIGNAL(id);
    this.active = false;
    this.listen = false;
    this.sigon = this.sigon.bind(this);
    this.sigoff = this.handler = debounce(this.sigoff.bind(this), 1000);
    this.unplug = this.unplug.bind(this);
  }

  on(callback: () => void) {
    const e = this.event;

    const n = e.listenerCount();
    e.on(callback);
    if (n === 0) {
      this.active = true;
      if (isRunning()) this.sigon();
    }
  }

  off(callback: () => void) {
    const e = this.event;
    e.off(callback);
    const n = e.listenerCount();
    if (n === 0) {
      this.active = false;
      if (isRunning()) this.sigoff();
    }
  }

  /* Bound to this */
  sigon() {
    if (this.active && !this.listen) {
      this.listen = true;
      client.sigOn(this.id);
    }
  }

  /* Bound to this, Debounced */
  sigoff() {
    if (!this.active && this.listen) {
      if (isRunning()) {
        this.listen = false;
        client.sigOff(this.id);
      }
    }
  }

  emit() {
    this.event.emit();
  }

  unplug() {
    this.listen = false;
    this.handler.cancel();
  }
}

// --- Memo

const signals: Map<string, SignalHandler> = new Map();

function _signal(id: string): SignalHandler {
  let s = signals.get(id);
  if (!s) {
    s = new SignalHandler(id);
    signals.set(id, s);
  }
  return s;
}

// --- External API

/**
 *  Register a callback for a signal.
 *
 *  If the server is not yet listening to this signal, a `SIGON` command is
 *  sent to the Frama-C server.
 *  @param {string} id The signal identifier to listen to.
 *  @param {function} callback The callback to call upon signal.
 */
export function onSignal(s: Signal, callback: () => void) {
  _signal(s.name).on(callback);
}

/**
 *  Unregister a callback of a signal.
 *
 *  When no more callbacks are listening to this signal for a while,
 *  the Frama-C server will be notified with a `SIGOFF` command.
 *  @param {string} id The signal identifier that was listen to.
 *  @param {function} callback The callback to remove.
 */
export function offSignal(s: Signal, callback: () => void) {
  _signal(s.name).off(callback);
}

/**
 *  Hook on a signal (Custom React Hook).
 *  @param {string} id The signal identifier to listen to.
 *  @param {function} callback The callback to call upon signal.
 */
export function useSignal(s: Signal, callback: () => void) {
  React.useEffect(() => {
    onSignal(s, callback);
    return () => { offSignal(s, callback); };
  });
}

// --- Server Synchro

READY.on(() => {
  signals.forEach((h: SignalHandler) => {
    h.sigon();
  });
});

SHUTDOWN.on(() => {
  signals.forEach((h: SignalHandler) => {
    h.unplug();
  });
});

// --------------------------------------------------------------------------
// --- REQUEST Management
// --------------------------------------------------------------------------

/** Request kind. */
export enum RqKind {
  /** Used to read data from the Frama-C server. */
  GET = 'GET',
  /** Used to write data into the Frama-C server. */
  SET = 'SET',
  /** Used to make the Frama-C server execute a task. */
  EXEC = 'EXEC',
}

/** Server signal. */
export interface Signal {
  name: string;
}

/** Server request. */
export interface Request<Kd extends RqKind, In, Out> {
  kind: Kd;
  /** The request full name. */
  name: string;
  /** Encoder of input parameters. */
  input: Json.Loose<In>;
  /** Decoder of output parameters. */
  output: Json.Loose<Out>;
  /** Signals the request depends on */
  signals: Array<Signal>;
}

export type GetRequest<In, Out> = Request<RqKind.GET, In, Out>;
export type SetRequest<In, Out> = Request<RqKind.SET, In, Out>;
export type ExecRequest<In, Out> = Request<RqKind.EXEC, In, Out>;

export interface Response<Data> extends Promise<Data> {
  kill?: () => void;
}

/**
 *  Send a request to the server.
 *
 *  You may _kill_ the request before its normal termination by
 *  invoking `kill()` on the returned promised.
 */
export function send<In, Out>(
  request: Request<RqKind, In, Out>,
  param: In,
): Response<Out> {
  if (!isRunning()) return Promise.reject('Server not running');
  if (!request.name) return Promise.reject('Undefined request');
  const rid = `RQ.${rqCount}`;
  rqCount += 1;
  const response: Response<Out> = new Promise<Out>((resolve, reject) => {
    const unwrap = (js: Json.json) => {
      const data = request.output(js);
      resolve(data as unknown as Out);
    };
    pending.set(rid, { resolve: unwrap, reject });
  });
  response.kill = () => pending.get(rid)?.reject();
  client.send(request.kind, rid, request.name, param);
  if (!pollingTimer) {
    const polling = (config && config.polling) || pollingTimeout;
    pollingTimer = setInterval(() => {
      client.poll();
    }, polling);
  }
  return response;
}

// --------------------------------------------------------------------------
// --- Client Events
// --------------------------------------------------------------------------

function _resolved(id: string) {
  pending.delete(id);
  if (pending.size == 0) {
    rqCount = 0;
    if (pollingTimer) {
      clearInterval(pollingTimer);
      pollingTimer = undefined;
    }
  }
}

client.onConnect((err?: Error) => {
  if (err) {
    _status(Status.FAILURE);
  } else {
    _status(Status.ON);
  }
});

client.onData((id: string, data: Json.json) => {
  const p = pending.get(id);
  if (p) {
    p.resolve(data);
    _resolved(id);
  }
});

client.onKilled((id: string) => {
  const p = pending.get(id);
  if (p) {
    p.reject();
    _resolved(id);
  }
});

client.onRejected((id: string) => {
  const p = pending.get(id);
  if (p) {
    p.reject('rejected');
    _resolved(id);
  }
});

client.onError((id: string, msg: string) => {
  const p = pending.get(id);
  if (p) {
    p.reject(msg);
    _resolved(id);
  }
});

client.onSignal((id: string) => {
  _signal(id).emit();
});

// --------------------------------------------------------------------------
