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
// --- Frama-C Server
// --------------------------------------------------------------------------

/**
 * Manage the current Frama-C server/client interface
 * @packageDocumentation
 * @module frama-c/server
*/

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as System from 'dome/system';
import * as Json from 'dome/data/json';
import { RichTextBuffer } from 'dome/text/buffers';
import { Request as ZmqRequest } from 'zeromq';
import { ChildProcess } from 'child_process';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const D = new Dome.Debug('Server');

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
export enum Stage {
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
  FAILURE = 'FAILURE'
}

export interface OkStatus {
  readonly stage:
  Stage.OFF | Stage.ON | Stage.STARTING | Stage.RESTARTING | Stage.HALTING;
}

export interface ErrorStatus {
  readonly stage: Stage.FAILURE;
  /** Failure message. */
  readonly error: string;
}

export type Status = OkStatus | ErrorStatus;

function okStatus(
  s: Stage.OFF | Stage.ON | Stage.STARTING | Stage.RESTARTING | Stage.HALTING,
) {
  return { stage: s };
}

function errorStatus(error: string): ErrorStatus {
  return { stage: Stage.FAILURE, error };
}

export function hasErrorStatus(s: Status): s is ErrorStatus {
  return (s as ErrorStatus).error !== undefined;
}

// --------------------------------------------------------------------------
// --- Server Global State
// --------------------------------------------------------------------------

/** The current server status. */
let status: Status = okStatus(Stage.OFF);

/** Request counter. */
let rqCount = 0;

type IndexedPair<T, U> = {
  [index: string]: [T, U];
};

type ResolvePromise = (value: Json.json) => void;
type RejectPromise = (error: Error) => void;

/** Pending promise callbacks (pairs of (resolve, reject)). */
let pending: IndexedPair<ResolvePromise, RejectPromise> = {};

/** Queue of server commands to be sent. */
let queueCmd: string[] = [];

/** Waiting request ids to be sent. */
let queueId: string[] = [];

/** Polling timeout and timer. */
const pollingTimeout = 50;
let pollingTimer: NodeJS.Timeout | undefined;

/** Flushing timer. */
let flushingTimer: NodeJS.Immediate | undefined;

/** Server process. */
let process: ChildProcess | undefined;

/** Killing timeout and timer for server process hard kill. */
const killingTimeout = 300;
let killingTimer: NodeJS.Timeout | undefined;

/** ZMQ (REQ) socket. */
let zmqSocket: ZmqRequest | undefined;
/** Flag on whether ZMQ socket is busy. */
let zmqIsBusy = false;

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
export function isRunning(): boolean { return status.stage === Stage.ON; }

/**
 *  Number of requests still pending.
 *  @return {number} Pending requests.
 */
export function getPending(): number {
  return _.reduce(pending, (n) => n + 1, 0);
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
  if (Dome.DEVEL && hasErrorStatus(newStatus)) {
    D.error(newStatus.error);
  }

  if (newStatus !== status) {
    const oldStatus = status;
    status = newStatus;
    STATUS.emit(newStatus);
    if (oldStatus.stage === Stage.ON) SHUTDOWN.emit();
    if (newStatus.stage === Stage.ON) READY.emit();
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
  switch (status.stage) {
    case Stage.OFF:
    case Stage.FAILURE:
    case Stage.RESTARTING:
      _status(okStatus(Stage.STARTING));
      try {
        await _launch();
        _status(okStatus(Stage.ON));
      } catch (error) {
        D.error(error.toString());
        buffer.append(error.toString(), '\n');
        _exit(error);
      }
      return;
    case Stage.HALTING:
      _status(okStatus(Stage.RESTARTING));
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
 *  - If the server is restarting, restart is canceled.
 *  - Otherwise, this is a no-op.
 */
export function stop() {
  switch (status.stage) {
    case Stage.STARTING:
      _status(okStatus(Stage.HALTING));
      _kill();
      return;
    case Stage.ON:
      _status(okStatus(Stage.HALTING));
      _shutdown();
      return;
    case Stage.RESTARTING:
      _status(okStatus(Stage.HALTING));
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
  switch (status.stage) {
    case Stage.STARTING:
    case Stage.ON:
    case Stage.HALTING:
    case Stage.RESTARTING:
      _status(okStatus(Stage.HALTING));
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
  switch (status.stage) {
    case Stage.OFF:
    case Stage.FAILURE:
      start();
      return;
    case Stage.ON:
      _status(okStatus(Stage.RESTARTING));
      _shutdown();
      return;
    case Stage.HALTING:
      _status(okStatus(Stage.RESTARTING));
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
  switch (status.stage) {
    case Stage.FAILURE:
    case Stage.OFF:
      buffer.clear();
      _status(okStatus(Stage.OFF));
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
  /** Server socket (default: `ipc:///.frama-c.<pid>.io`). */
  sockaddr?: string;
  /** Shutdown timeout before server is hard killed, in milliseconds
   *  (default: 300ms). */
  timeout?: number;
  /** Server polling period in milliseconds (default: 50ms). */
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
  const size = params.reduce((n: any, p: any) => n + p.length, 0);
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

  if (!cwd) cwd = System.getWorkingDir();
  if (!sockaddr) {
    const socketfile = System.join(cwd, `.frama-c.${System.getPID()}.io`);
    System.atExit(() => System.remove(socketfile));
    sockaddr = `ipc://${socketfile}`;
  }
  logout = logout && System.join(cwd, logout);
  logerr = logerr && System.join(cwd, logerr);
  params = ['-server-zmq', sockaddr, '-then'].concat(params);
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
    D.log('Process exited');

    if (signal) {
      // [signal] is non-null.
      buffer.log('Signal:', signal);
      const error = new Error(`Process terminated by the signal ${signal}`);
      _exit(error);
      return;
    }
    // [signal] is null, hence [code] is non-null (cf. NodeJS doc).
    if (code) {
      buffer.log('Exit:', code);
      const error = new Error(`Process exited with code ${code}`);
      _exit(error);
    } else {
      // [code] is zero: normal exit w/o error.
      _exit();
    }
  });
  // Connect to Server
  zmqSocket = new ZmqRequest();
  zmqIsBusy = false;
  zmqSocket.connect(sockaddr);
}

// --------------------------------------------------------------------------
// --- Low-level Killing
// --------------------------------------------------------------------------

function _reset() {
  D.log('Reset to initial configuration');

  rqCount = 0;
  queueCmd = [];
  queueId = [];
  _.forEach(pending, ([, reject]) => reject(new Error('Server reset')));
  pending = {};
  if (flushingTimer) {
    clearImmediate(flushingTimer);
    flushingTimer = undefined;
  }
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
  D.log('Hard kill');

  _reset();
  if (process) {
    process.kill();
  }
}

async function _shutdown() {
  D.log('Shutdown');

  _reset();
  queueCmd.push('SHUTDOWN');
  _flush();
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

function _exit(error?: Error) {
  _reset();
  if (zmqSocket) {
    zmqSocket.close();
    zmqSocket = undefined;
  }
  zmqIsBusy = false;
  process = undefined;
  if (status.stage === Stage.RESTARTING) {
    setImmediate(start);
  } else if (error) {
    _status(errorStatus(error.toString()));
  } else {
    _status(okStatus(Stage.OFF));
  }
}

// --------------------------------------------------------------------------
// --- Signal Management
// --------------------------------------------------------------------------

class SignalHandler {
  id: any;
  event: Dome.Event;
  active: boolean;
  listen: boolean;

  constructor(id: any) {
    this.id = id;
    this.event = new SIGNAL(id);
    this.active = false;
    this.listen = false;
    this.sigon = this.sigon.bind(this);
    this.sigoff = _.debounce(this.sigoff.bind(this), 1000);
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
      queueCmd.push('SIGON', this.id);
      _flush();
    }
  }

  /* Bound to this, Debounced */
  sigoff() {
    if (!this.active && this.listen) {
      if (isRunning()) {
        this.listen = false;
        queueCmd.push('SIGOFF', this.id);
        _flush();
      }
    }
  }

  unplug() {
    this.listen = false;
  }
}

// --- Memo

const signals: Map<string, SignalHandler> = new Map();

function _signal(id: any) {
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
export function onSignal(s: Signal, callback: any) {
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
export function offSignal(s: Signal, callback: any) {
  _signal(s.name).off(callback);
}

/**
 *  Hook on a signal (Custom React Hook).
 *  @param {string} id The signal identifier to listen to.
 *  @param {function} callback The callback to call upon signal.
 */
export function useSignal(s: Signal, callback: any) {
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
    (h.sigoff as unknown as _.Cancelable).cancel();
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
  EXEC = 'EXEC'
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
}

/** Server signal. */
export interface Signal {
  name: string;
}

export type GetRequest<In, Out> = Request<RqKind.GET, In, Out>;
export type SetRequest<In, Out> = Request<RqKind.SET, In, Out>;
export type ExecRequest<In, Out> = Request<RqKind.EXEC, In, Out>;

export interface Killable<Data> extends Promise<Data> {
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
): Killable<Out> {
  if (!isRunning()) return Promise.reject(new Error('Server not running'));
  if (!request.name) return Promise.reject(new Error('Undefined request'));
  const rid = `RQ.${rqCount}`;
  rqCount += 1;
  const data = JSON.stringify(param);
  const promise: Killable<Out> = new Promise<Out>((resolve, reject) => {
    const decodedResolve = (js: Json.json) => {
      const result = Json.jTry(request.output)(js);
      resolve(result);
    };
    pending[rid] = [decodedResolve, reject];
  });
  promise.kill = () => {
    if (zmqSocket && pending[rid]) {
      queueCmd.push('KILL', rid);
      _flush();
    }
  };
  queueCmd.push(request.kind, rid, request.name, data);
  queueId.push(rid);
  _flush();
  return promise;
}

function _resolve(id: string | number, data: string) {
  const [resolve] = pending[id];
  if (resolve) {
    delete pending[id];
    resolve(JSON.parse(data));
  }
}

function _reject(id: string | number, error: Error) {
  const [, reject] = pending[id];
  if (reject) {
    delete pending[id];
    reject(error);
  }
}

function _cancel(ids: any[]) {
  ids.forEach((rid) => _reject(rid, new Error('Canceled request')));
}

function _waiting() {
  return _.find(pending, () => true) !== undefined;
}

// --------------------------------------------------------------------------
// --- Server Command Queue
// --------------------------------------------------------------------------

function _flush() {
  if (!flushingTimer) {
    flushingTimer = setImmediate(() => {
      flushingTimer = undefined;
      _send();
    });
  }
}

function _poll() {
  if (!pollingTimer) {
    const delay = (config && config.polling) || pollingTimeout;
    pollingTimer = setTimeout(() => {
      pollingTimer = undefined;
      _send();
    }, delay);
  }
}

async function _send() {
  // when busy, will be eventually re-triggered
  if (!zmqIsBusy) {
    const cmds = queueCmd;
    if (!cmds.length && _waiting()) cmds.push('POLL');
    if (cmds.length) {
      zmqIsBusy = true;
      const ids = queueId;
      queueCmd = [];
      queueId = [];
      try {
        await zmqSocket?.send(cmds);
        const resp = await zmqSocket?.receive();
        _receive(resp);
      } catch (error) {
        D.error(`Error in send/receive on ZMQ socket. ${error.toString()}`);
        _cancel(ids);
      }
      zmqIsBusy = false;
    } else {
      // No pending command nor pending response
      rqCount = 0;
    }
    STATUS.emit(status);
  }
}

function _receive(resp: any) {
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
          _resolve(rid, data);
          break;
        case 'KILLED':
          rid = shift();
          _reject(rid, new Error('Killed'));
          break;
        case 'ERROR':
          rid = shift();
          err = shift();
          _reject(rid, err);
          break;
        case 'REJECTED':
          rid = shift();
          _reject(rid, new Error('Rejected'));
          break;
        case 'SIGNAL':
          rid = shift();
          (new SIGNAL(rid)).emit();
          break;
        case 'WRONG':
          err = shift();
          D.error(`ZMQ Protocol Error: ${err}`);
          break;
        default:
          D.error(`Unknown Response: ${cmd}`);
          unknownResponse = true;
          break;
      }
    }
  } finally {
    if (queueCmd.length) _flush();
    else _poll();
  }
}

// --------------------------------------------------------------------------
