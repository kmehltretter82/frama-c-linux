// --------------------------------------------------------------------------
// --- Frama-C Server
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module frama-c/server
   @description
   Manage the current Frama-C server/client interface
*/

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as System from 'dome/system';
import { RichTextBuffer } from 'dome/text/buffers';
import { Request as ZmqRequest } from 'zeromq';
import { ChildProcess } from 'child_process';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

class PP {
  static warning(t: string) { console.warn(`[Frama-C Server] ${t}.`); }
  static error(t: string) { console.error(`[Frama-C Server] ${t}.`); }
}

// --------------------------------------------------------------------------
// --- Events
// --------------------------------------------------------------------------

/**
 *  @event
 *  @name 'frama-c.server.status'
 *  @summary Server Status Notification Event
 *  @description
 *  This event is emitted whenever the server status changes.
 */
const STATUS = 'frama-c.server.status';

/**
 *  @event
 *  @name 'frama-c.server.ready'
 *  @summary Server is actually started and running.
 *  @description
 *  This event is emitted when ther server _enters_ the `ON` state.
 *  It is now ready to handle requests.
 */
const READY = 'frama-c.server.ready';

/**
 *  @event
 *  @name 'frama-c.server.shutdown'
 *  @summary Server Status Notification Event
 *  @description
 *  This event is emitted when ther server _leaves_ the `ON` state.
 *  It is no more able to handle requests until re-start.
 */
const SHUTDOWN = 'frama-c.server.shutdown';

/**
 *  @event
 *  @name 'frama-c.server.signal.*'
 *  @summary Server Signal Prefix
 *  @description
 *  Event `frama-c.server.signal.<id>'` for signal `<id>`.
 */
const SIGNAL = 'frama-c.server.signal.';

/**
 *  @event
 *  @name 'frama-c.server.activity.*'
 *  @summary Server Signal Activity Prefix
 *  @param {boolean} active - whether the server is listening or not to the
 *  signal.
 *  @description
 *  Event `frama-c.server.activity.<id>'` for signal `<id>`.
 */
const ACTIVITY = 'frama-c.server.activity.';

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
type ResolvePromise = (value?: any) => void;
type RejectPromise = (error: Error) => void;

/** Pending promise callbacks (pairs of (resolve, reject)). */
let pending: IndexedPair<ResolvePromise, RejectPromise> = {};

/** Queue of server commands to be sent. */
let queueCmd: string[] = [];

/** Waiting request ids to be sent. */
let queueId: string[] = [];

/** Polling timeout and timer. */
const pollingTimeout = 50;
let pollingTimer: NodeJS.Timeout | null = null;

/** Flushing timer. */
let flushingTimer: NodeJS.Immediate | null = null;

/** Server process. */
let process: ChildProcess | null = null;

/** Killing timeout and timer for server process hard kill. */
const killingTimeout = 300;
let killingTimer: NodeJS.Timeout | null = null;

/** ZMQ (REQ) socket. */
let zmqSocket: ZmqRequest | null = null;
/** Flag on whether ZMQ socket is busy. */
let zmqIsBusy = false;

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

export const buffer = new RichTextBuffer({ maxlines: 200 });

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/**
 *  @summary Current Server Status.
 *  @return {Status} the current server status
 *  @description
 *  See [STATUS](module-frama-c_server.html#~STATUS) code definitions.
 */
export function getStatus() { return status; }

/**
 *  @summary Hook on current server (Custom React Hook).
 *  @return {Status} the current server status
 *  @description
 *  See [STATUS](module-frama-c_server.html#~STATUS) code definitions.
 */
export function useStatus() {
  Dome.useUpdate(STATUS);
  return status;
}

/**
 *  @summary Frama-C Server is running and ready to handle requests.
 *  @return {boolean} Whether status is `ON`.
 */
export function isRunning() { return status.stage === Stage.ON; }

/**
 *  @summary Number of requests still pending.
 *  @return {number} pending requests
 */
export function getPending(): number {
  return _.reduce(pending, (n) => n + 1, 0);
}

/**
 *  @summary Register callback on READY event.
 *  @param {function} callback - invoked when the server enters `ON` status
 */
export function onReady(callback: any) { Dome.on(READY, callback); }

/**
 *  @summary Register callback on SHUTDOWN event.
 *  @param {function} callback - invoked when the server enters SHUTDOWN status
 */
export function onShutdown(callback: any) { Dome.on(SHUTDOWN, callback); }

/**
 *  @summary Register callback on Signal ACTIVITY event.
 *  @*param {string} id - the signal event to listen to
 *  @*param {function} callback - invoked with `callback(signal,active)`
 */
export function onActivity(signal: string, callback: any) {
  Dome.on(ACTIVITY + signal, callback);
}

// --------------------------------------------------------------------------
// --- Status Update
// --------------------------------------------------------------------------

function _status(newStatus: Status) {
  if (Dome.DEVEL && hasErrorStatus(newStatus)) {
    PP.error(newStatus.error);
  }

  if (newStatus !== status) {
    const oldStatus = status;
    status = newStatus;
    Dome.emit(STATUS);
    if (oldStatus.stage === Stage.ON) Dome.emit(SHUTDOWN);
    if (newStatus.stage === Stage.ON) Dome.emit(READY);
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Start)
// --------------------------------------------------------------------------

/**
 *  @summary Start the Server.
 *  @description
 *  If the server is started or running, this is a no-op.
 *  If the server is being shutdown, it will reboot.
 *  Otherwise, the Frama-C Server is spawned.
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
        PP.error(error.toString());
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
 *  @summary Stop the Server.
 *  @description
 *  If the server is starting, it is hard killed.
 *  If the server is running, it is shutdown gracefully.
 *  When the server is shutting down, restart is canceled.
 *  Otherwise, this is a no-op.
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
 *  @summary Terminate the Server.
 *  @description
 *  If the server is starting or running or shutting down,
 *  it is hard killed and restart is canceled.
 *  Otherwize, this is no-op.
 *
 *  This function is automatically called when the `module` emits the `KILL`
 *  signal.
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
 *  @summary Re-start the Server.
 *  @description
 *  If paused, simply start the Server.
 *  When running, try to gracefully shutdown the Server,
 *  and finally schedule a reboot on exit.
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
 *  @summary Acknowledge `FAILURE` status.
 *  @description
 *  When not running, clear the console and reset any error flag.
 *  Otherwised, do nothing.
 */
export function clear() {
  switch (status.stage) {
    case Stage.FAILURE:
      buffer.clear();
      _status(okStatus(Stage.OFF));
      return;
    case Stage.OFF:
      buffer.clear();
      Dome.emit(STATUS);
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
 *  @summary Configure the Server.
 *  @param {Configuration} sc - Server Configuration
 */
export function configure(sc: Configuration) {
  config = { ...sc };
}

/**
 *  @summary Configure the Server.
 *  @return {object} server configuration
 *  @description
 *  See `configure()` method.
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
      buffer.scroll(undefined, undefined);
    }
  };
  process?.stdout?.on('data', logger);
  process?.stderr?.on('data', logger);
  process?.on('exit', (code: number | null, signal: string | null) => {
    PP.warning('Process exited');

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
  PP.warning('Reset to initial configuration');

  rqCount = 0;
  queueCmd = [];
  queueId = [];
  _.forEach(pending, ([, reject]) => reject(new Error('Server reset')));
  pending = {};
  if (flushingTimer) {
    clearImmediate(flushingTimer);
    flushingTimer = null;
  }
  if (pollingTimer) {
    clearTimeout(pollingTimer);
    pollingTimer = null;
  }
  if (killingTimer) {
    clearTimeout(killingTimer);
    killingTimer = null;
  }
}

function _kill() {
  PP.warning('Hard kill');

  _reset();
  if (process) {
    process.kill();
  }
}

async function _shutdown() {
  PP.warning('Shutdown');

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
    zmqSocket = null;
  }
  zmqIsBusy = false;
  process = null;
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

class Signal {
  id: any;
  event: string;
  active: boolean;
  listen: boolean;

  constructor(id: any) {
    this.id = id;
    this.event = SIGNAL + id;
    this.active = false;
    this.listen = false;
    this.sigon = this.sigon.bind(this);
    this.sigoff = _.debounce(this.sigoff.bind(this), 1000);
    this.unplug = this.unplug.bind(this);
  }

  on(callback: any) {
    const n = Dome.emitter.listenerCount(this.event);
    Dome.on(this.event, callback);
    if (n === 0) {
      this.active = true;
      if (isRunning()) this.sigon();
    }
  }

  off(callback: any) {
    Dome.off(this.event, callback);
    const n = Dome.emitter.listenerCount(this.event);
    if (n === 0) {
      this.active = false;
      if (isRunning()) this.sigoff();
    }
  }

  /* Bound to this */
  sigon() {
    if (this.active && !this.listen) {
      Dome.emit(ACTIVITY + this.id, true);
      this.listen = true;
      queueCmd.push('SIGON', this.id);
      _flush();
    }
  }

  /* Bound to this, Debounced */
  sigoff() {
    if (!this.active && this.listen) {
      Dome.emit(ACTIVITY + this.id, false);
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

const signals: Map<string, Signal> = new Map();
function _signal(id: any) {
  let s = signals.get(id);
  if (!s) {
    s = new Signal(id);
    signals.set(id, s);
  }
  return s;
}

// --- External API

/**
 *  @summary Register a Signal callback.
 *  @param {string} id - the signal event to listen to
 *  @param {function} callback - the callback to call on received signal
 *  @description
 *  If the server is not yet listening to this signal, a `SIGON` command is
 *  sent.
 */
export function onSignal(id: string, callback: any) {
  _signal(id).on(callback);
}

/**
 *  @summary Un-register a Signal callback.
 *  @param {string} id - the signal event that was listen to
 *  @param {function} callback - the callback to remove
 *  @description
 *  When no more callbacks are listening to this signal for a while,
 *  the server will be notified with a `SIGOFF` command.
 */
export function offSignal(id: string, callback: any) {
  _signal(id).off(callback);
}

/**
 *  @summary Hook on Signal (Custom React Hook).
 *  @param {string} id - the signal event to listen to
 *  @param {function} callback - the callback to be called on signal
 */
export function useSignal(id: string, callback: any) {
  React.useEffect(() => {
    onSignal(id, callback);
    return () => { offSignal(id, callback); };
  });
}

// --- Server Synchro

Dome.on(READY, () => {
  signals.forEach((signal: Signal) => {
    signal.sigon();
  });
});

Dome.on(SHUTDOWN, () => {
  signals.forEach((signal: Signal) => {
    signal.unplug();
    (signal.sigoff as unknown as _.Cancelable).cancel();
  });
});

// --------------------------------------------------------------------------
// --- REQUEST Management
// --------------------------------------------------------------------------

/**
 *  @typedef RqKind
 *  @summary Request kind.
 *  @description
 *   - `R_GET` Used to read data from the server
 *   - `R_SET` Used to write data into the server
 *   - `R_EXEC` Used to make the server execute a task
 */
export enum RqKind {
  R_GET = 'GET',
  R_SET = 'SET',
  R_EXEC = 'EXEC'
}

/**
 * @typedef Request
 * @summary Server request.
 * @param {string} endpoint - the request identifier
 * @param {any} params - the request parameters
 */
export interface Request {
  endpoint: string;
  params: any;
}

/**
 * @summary Get data from the server.
 * @param sr - the server request description.
 */
export async function GET(sr: Request) {
  return send(RqKind.R_GET, sr.endpoint, sr.params);
}

/**
 * @summary Set data into the server.
 * @param sr - the server request description.
 */
export async function SET(sr: Request) {
  return send(RqKind.R_SET, sr.endpoint, sr.params);
}

/**
 * @summary Make the server execute a task.
 * @param sr - the server request description.
 */
export async function EXEC(sr: Request) {
  return send(RqKind.R_EXEC, sr.endpoint, sr.params);
}

/**
 *  @summary Send a request to the server.
 *  @param {RqKind} kind - the request kind
 *  @param {string} rq - the request identifier
 *  @param {object} params - request parameters
 *  @return {Promise<object>} the promised request results
 *  @description
 *  You may _kill_ the request before its normal termination by
 *  invoking `kill()` on the returned promised.
 */
function send(kind: RqKind, rq: string, params: any) {
  if (!isRunning()) return Promise.reject(new Error('Server not running'));
  if (!rq) return Promise.reject(new Error('Undefined request'));
  const rid = `RQ.${rqCount}`;
  rqCount += 1;
  const data = JSON.stringify(params);
  const promise: any = new Promise((resolve, reject) => {
    pending[rid] = [resolve, reject];
  });
  promise.kill = () => {
    if (zmqSocket && pending[rid]) {
      queueCmd.push('KILL', rid);
      _flush();
    }
  };
  queueCmd.push(kind, rid, rq, data);
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
      flushingTimer = null;
      _send();
    });
  }
}

function _poll() {
  if (!pollingTimer) {
    const delay = (config && config.polling) || pollingTimeout;
    pollingTimer = setTimeout(() => {
      pollingTimer = null;
      _send();
    }, delay);
  }
}

function _send() {
  // when busy, will be eventually re-triggered
  if (!zmqIsBusy) {
    const cmds = queueCmd;
    if (!cmds.length && _waiting()) cmds.push('POLL');
    if (cmds.length) {
      const ids = queueId;
      queueCmd = [];
      queueId = [];
      if (zmqSocket) {
        zmqIsBusy = true;
        zmqSocket.send(cmds)
          .then(() => zmqSocket?.receive().then((resp: any) => _receive(resp)))
          .catch(() => _cancel(ids))
          .finally(() => { zmqIsBusy = false; Dome.emit(STATUS); });
      } else {
        _cancel(ids);
      }
    } else {
      // No pending command nor pending response
      rqCount = 0;
    }
    Dome.emit(STATUS);
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
          Dome.emit(SIGNAL + rid);
          break;
        case 'WRONG':
          err = shift();
          PP.error(`ZMQ Protocol Error: ${err}`);
          break;
        default:
          PP.error(`Unknown Response: ${cmd}`);
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
