// --------------------------------------------------------------------------
// --- Frama-C Server
// --------------------------------------------------------------------------

/**
 *  @module frama-c/server
 *  @description Manage the current Frama-C server/client interface
 */

import _ from 'lodash'
import React from 'react'
import Dome from 'dome'
import System from 'dome/system'
import { Buffer } from 'dome/text/buffers'
import { Request } from 'zeromq'

// --------------------------------------------------------------------------
// --- Events
// --------------------------------------------------------------------------

/**
 *  @event
 *  @name 'frama-c.server.status'
 *  @summary Server Status Notification Event
 *  @description
 *  This event is emitted whenever the server status changes.
 *
 *  Exported as `Server.STATUS' in public API.
 */
export const STATUS = 'frama-c.server.status';

/**
 *  @event
 *  @name 'frama-c.server.ready'
 *  @summary Server is actually started and running.
 *  @description
 *  This event is emitted when ther server _enters_ the `RUNNING` state.
 *  It is now ready to handle requests.
 *
 *  Exported as `Server.READY' in public API.
 */
export const READY = 'frama-c.server.ready';

/**
 *  @event
 *  @name 'frama-c.server.shutdown'
 *  @summary Server Status Notification Event
 *  @description
 *  This event is emitted when ther server _leaves_ the `RUNNING` state.
 *  It is no more able to handle requests until re-start.
 *
 *  Exported as `Server.SHUTDOWN' in public API.
 */
export const SHUTDOWN = 'frama-c.server.shutdown';

/**
 *  @event
 *  @name 'frama-c.server.signal.*'
 *  @summary Server Signal Prefix
 *  @description
 *  Event `frama-c.server.signal.<id>'` for signal `<id>`.
 *  The prefix `'frama-c.server.signal.'` is exported as `Server.SIGNAL` in
 *  public API.
 */
export const SIGNAL = 'frama-c.server.signal.';

/**
 *  @event
 *  @name 'frama-c.server.activity.*'
 *  @summary Server Signal Activity Prefix
 *  @param {boolean} active - whether the server is listening or not to the
 *  signal.
 *  @description
 *  Event `frama-c.server.activity.<id>'` for signal `<id>`.
 *  The prefix `'frama-c.server.activity.'` is exported as
 *  `Server.ACTIVITY` in public API.
 */
export const ACTIVITY = 'frama-c.server.activity.';

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/**
 *  @typedef STATUS_CODE
 *  @summary Server Status Codes.
 *  @description
 *   - `OFF` Server off
 *   - `STARTED` Frama-C command launched
 *   - `RUNNING` Server ready
 *   - `KILLING` Server shutdown, waiting for exit
 *   - `RESTART` Server shutdown, will reboot on exit
 *   - `FAILED` Server halted on error
 */
export enum STATUS_CODE {
  OFF = 'OFF',
  STARTED = 'STARTED',
  RUNNING = 'RUNNING',
  KILLING = 'KILLING',
  RESTART = 'RESTART',
  FAILED = 'FAILED'
}

// --------------------------------------------------------------------------
// --- Server Global State
// --------------------------------------------------------------------------

let status = STATUS_CODE.OFF;
let error: any;     // process error
let rqid: any;      // Request ID
let pending: any;   // Pending promise callbacks
let queueCmd: any; // Queue of server commands to be sent
let queueIds: any; // Waiting request ids to be sent
let polling: any;   // Timeout Polling timer
let flushing: any;  // Immediate Flushing timer
let config: any;    // Server config
let process: any;   // Server process
let socket: any;    // ZMQ (REQ) socket
let busy: any;      // ZMQ socket is busy
let killing: any;   // killing timeout

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

export const buffer = new Buffer({ maxlines: 200 });
export const feedback = '';

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/**
 *  @summary Current Server Status.
 *  @return {STATUS_CODE} the current server status
 *  @description
 *  See [STATUS](module-frama-c_server.html#~STATUS) code definitions.
 */
export function getStatus(): STATUS_CODE { return status }

/**
 *  @summary Hook on current server (Custom React Hook).
 *  @return {STATUS_CODE} the current server status
 *  @description
 *  See [STATUS](module-frama-c_server.html#~STATUS) code definitions.
 */
export function useStatus(): STATUS_CODE {
  Dome.useUpdate(STATUS);
  return status;
}

/** Return `FAILED` status message. */
export function getError() { return error; }

/**
 *  @summary Frama-C Server is running and ready to handle requests.
 *  @return {boolean} status is `RUNNING`.
 */
export function isRunning(): boolean { return status === STATUS_CODE.RUNNING }

/**
 *  @summary Number of requests still pending.
 *  @return {number} pending requests
 */
export function getPending(): number {
  return _.reduce(pending, (_, n) => n + 1, 0)
}

/**
 *  @summary Register callback on READY event.
 *  @param {function} callback - invoked when the server enters RUNNING status
 */
export function onReady(callback: any) { Dome.on(READY, callback) }

/**
 *  @summary Register callback on SHUTDOWN event.
 *  @param {function} callback - invoked when the server enters SHUTDOWN status
 */
export function onShutdown(callback: any) { Dome.on(SHUTDOWN, callback) }

/**
 *  @summary Register callback on Signal ACTIVITY event.
 *  @*param {string} id - the signal event to listen to
 *  @*param {function} callback - invoked with `callback(signal,active)`
 */
export function onActivity(signal: string, callback: any) {
  Dome.on(ACTIVITY + signal, callback)
}

// --------------------------------------------------------------------------
// --- Status Update
// --------------------------------------------------------------------------

function _status(newStatus: STATUS_CODE, err: string | null) {
  if (Dome.DEVEL && err) console.error('[Server]', err);
  if (newStatus !== status || err) {
    const oldStatus = status;
    status = newStatus;
    error = err ? err.toString() : undefined;
    Dome.emit(STATUS);
    if (oldStatus === STATUS_CODE.RUNNING) Dome.emit(SHUTDOWN);
    if (newStatus === STATUS_CODE.RUNNING) Dome.emit(READY);
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
export function start() {
  switch (status) {
    case STATUS_CODE.OFF:
    case STATUS_CODE.FAILED:
      _status(STATUS_CODE.STARTED, null);
      _launch()
        .then(() => _status(STATUS_CODE.RUNNING, null))
        .catch((err) => _status(STATUS_CODE.FAILED, err));
      return;
    case STATUS_CODE.KILLING:
      _status(STATUS_CODE.RESTART, null);
      return;
    case STATUS_CODE.STARTED:
    case STATUS_CODE.RUNNING:
    case STATUS_CODE.RESTART:
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
  switch (status) {
    case STATUS_CODE.STARTED:
      _kill();
      _status(STATUS_CODE.KILLING, null);
      return;
    case STATUS_CODE.RUNNING:
      _shutdown();
      _status(STATUS_CODE.KILLING, null);
      return;
    case STATUS_CODE.RESTART:
      _status(STATUS_CODE.KILLING, null);
      return;
    case STATUS_CODE.OFF:
    case STATUS_CODE.FAILED:
    case STATUS_CODE.KILLING:
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
 *  This function is automatically called when the `module` emits the `KILL` signal.
 */
export function kill() {
  switch (status) {
    case STATUS_CODE.STARTED:
    case STATUS_CODE.RUNNING:
    case STATUS_CODE.KILLING:
    case STATUS_CODE.RESTART:
      _kill();
      _status(STATUS_CODE.KILLING, null);
      return;
    case STATUS_CODE.OFF:
    case STATUS_CODE.FAILED:
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
  switch (status) {
    case STATUS_CODE.OFF:
    case STATUS_CODE.FAILED:
      start();
      return;
    case STATUS_CODE.RUNNING:
      _shutdown();
      _status(STATUS_CODE.RESTART, null);
      return;
    case STATUS_CODE.KILLING:
      _status(STATUS_CODE.RESTART, null);
      return;
    case STATUS_CODE.STARTED:
    case STATUS_CODE.RESTART:
    default:
      return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Reset)
// --------------------------------------------------------------------------

/**
 *  @summary Acknowledge `FAILED` status.
 *  @description
 *  When not running, clear the console and reset any error flag.
 *  Otherwised, do nothing.
 */
export function clear() {
  switch (status) {
    case STATUS_CODE.FAILED:
      _status(STATUS_CODE.OFF, null);
      buffer.clear();
      Dome.emit(STATUS);
      return;
    case STATUS_CODE.OFF:
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

interface ServerConfiguration {
  env: any;         // Process environment variables (default: `undefined`)
  cwd: string;      // Working directory (default: current)
  command: string;  // Server command (default: `frama-c`)
  params: string[]; // Additional server arguments (default: empty)
  sockaddr: string; // Server socket (default: `ipc:///.frama-c.<pid>.io`)
  timeout: number;  // Shutdown timeout before server is hard killed, in milliseconds (default: 300ms)
  polling: number;  // Server polling period, in milliseconds (default: 50ms)
  logout: string;   // Process stdout log file (default: `undefined`)
  logerr: string;   // Process stderr log file (default: `undefined`)
}

/**
 *  @summary Configure the Server.
 *  @param {object} config - Server Configuration
 *  @param {object} [config.env]
 *  @param {string} [config.cwd]
 *  @param {string} [config.command]
 *  @param {Array.<string>} [config.params]
 *  @param {string} [config.sockaddr]
 *  @param {number} [config.timeout]
 *  @param {number} [config.polling]
 *  @param {string} [config.logout]
 *  @param {string} [config.logerr]
 */
export function configure(cfg: ServerConfiguration) {
  config = cfg || {};
}

/**
 *  @summary Configure the Server.
 *  @return {object} server configuration
 *  @description
 *  See `configure()` method.
 */
export function getConfig(): ServerConfiguration {
  return config;
}

// --------------------------------------------------------------------------
// --- Low-level Launching
// --------------------------------------------------------------------------

async function _launch() {
  _reset();
  if (!config) throw ('Frama-C Server not configured');
  let { env, cwd, command = 'frama-c', params = [], sockaddr, logout, logerr } = config;

  buffer.clear();
  buffer.append('$', command);
  const size = params.reduce((n: any, p: any) => n + p.length, 0);
  if (size < 40)
    buffer.append('', ...params);
  else
    params.forEach((argv: string) => {
      if (argv.startsWith('-') || argv.endsWith('.c') || argv.endsWith('.i') || argv.endsWith('.h'))
        buffer.append('\n    ');
      buffer.append(' ');
      buffer.append(argv);
    });
  buffer.append('\n');

  if (!cwd) cwd = System.getWorkingDir();
  if (!sockaddr) {
    const socketfile = System.join(cwd, '.frama-c.' + System.getPID() + '.io');
    System.atExit(() => System.remove(socketfile));
    sockaddr = 'ipc://' + socketfile;
  }
  logout = logout && System.join(cwd, logout);
  logerr = logerr && System.join(cwd, logerr);
  params = ['-server-zmq', sockaddr, '-then'].concat(params);
  const options = {
    cwd,
    stdout: { path: logout, pipe: true },
    stderr: { path: logerr, pipe: true },
    env
  };
  // Launch Process
  const process = await System.spawn(command, params, options);
  const logger = (text: string | string[]) => {
    buffer.append(text);
    if (0 <= text.indexOf('\n'))
      buffer.scroll(undefined, undefined);
  };
  process.stdout.on('data', logger);
  process.stderr.on('data', logger);
  process.on('error', (err: any) => {
    buffer.append('Error:', err, '\n');
    _close(err);
  });
  process.on('exit', (status: STATUS_CODE, signal: string) => {
    signal && buffer.log('Signal:', signal);
    status && buffer.log('Exit:', status);
    _close(signal || status);
  });
  // Connect to Server
  socket = new Request();
  busy = false;
  socket.connect(sockaddr);
}

// --------------------------------------------------------------------------
// --- Low-level Killing
// --------------------------------------------------------------------------

function _reset() {
  rqid = 0;
  process = undefined;
  queueCmd = [];
  queueIds = [];
  _.forEach(pending, ({ reject }) => reject('shutdown'));
  pending = {};
  if (flushing) clearImmediate(flushing);
  flushing = undefined;
  if (polling) clearTimeout(polling);
  polling = undefined;
}

function _kill() {
  _reset();
  if (killing) clearTimeout(killing);
  if (process) process.kill();
}

function _shutdown() {
  _reset();
  queueCmd.push('SHUTDOWN');
  _flush();
  if (!killing) {
    if (process) {
      const timeout = (config && config.timeout) || 300;
      killing = setTimeout(() => process.kill(), timeout);
    }
  }
}

function _close(error: string) {
  _reset();
  if (killing) {
    clearTimeout(killing);
    killing = undefined;
  }
  if (socket) {
    socket.close();
    socket = undefined;
    busy = false;
  }
  if (process) {
    process.kill();
    process = undefined;
  }
  if (error) {
    _status(STATUS_CODE.FAILED, error);
  } else {
    if (status === STATUS_CODE.RESTART) setImmediate(start);
    _status(STATUS_CODE.OFF, null);
  }
}

// --------------------------------------------------------------------------
// --- Request Queue
// --------------------------------------------------------------------------

/**
 *  @summary Send a GET request to the server.
 *  @param {string} rq - the request identifier
 *  @param {object} params - request parameters
 *  @return {Promise<object>} the promised request results
 *  @description
 *  You may _kill_ the request before its normal termination by
 *  invoking `kill()` on the returned promised.
 */
export function sendGET(rq: string, params: null | any) { return _sendRequest('GET', rq, params) }

/**
 *  @summary Send a SET request to the server.
 *  @param {string} rq - the request identifier
 *  @param {object} params - request parameters
 *  @return {Promise<object>} the promised request results
 *  @description
 *  You may _kill_ the request before its normal termination by
 *  invoking `kill()` on the returned promised.
 */
export function sendSET(rq: string, params: null | any) { return _sendRequest('SET', rq, params) }

/**
 *  @summary Send an EXEC request to the server.
 *  @param {string} rq - the request identifier
 *  @param {object} params - request parameters
 *  @return {Promise<object>} the promised request results
 *  @description
 *  You may _kill_ the request before its normal termination by
 *  invoking `kill()` on the returned promised.
 */
export function sendEXEC(rq: string, params: null | any) { return _sendRequest('EXEC', rq, params) }

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

}

//--- Memo

const signals: any[] = [];
function _signal(id: any) {
  let s = signals[id];
  if (!s) s = signals[id] = new Signal(id);
  return s;
}

//--- External API

/**
 *  @summary Register a Signal callback.
 *  @param {string} id - the signal event to listen to
 *  @param {function} callback - the callback to call on received signal
 *  @description
 *  If the server is not yet listening to this signal, a `SIGON` command is sent.
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
  })
}

//--- Server Synchro

Dome.on(READY, () => {
  _.forEach(signals, (s) => s.sigon());
});

Dome.on(SHUTDOWN, () => {
  _.forEach(signals, (s) => s.sigoff.cancel());
});

// --------------------------------------------------------------------------
// --- REQUEST Management
// --------------------------------------------------------------------------

function _sendRequest(kind: string, rq: any, params: null | string = null) {
  if (!isRunning()) return Promise.reject('Server not running');
  if (!rq) return Promise.reject('Undefined request');
  const rid = 'RQ.' + rqid++;
  const data = JSON.stringify(params);
  const promise: any = new Promise((resolve, reject) => {
    pending[rid] = { resolve, reject };
  });
  promise.kill = () => {
    if (socket && pending[rid]) {
      queueCmd.push('KILL', rid);
      _flush();
    }
  };
  queueCmd.push(kind, rid, rq, data);
  queueIds.push(rid);
  _flush();
  return promise;
}

function _resolve(id: string | number, data: string) {
  const promise = pending[id];
  if (promise) {
    delete pending[id];
    promise.resolve(JSON.parse(data));
  }
}

function _reject(id: string | number, error: string) {
  const promise = pending[id];
  if (promise) {
    delete pending[id];
    promise.reject(error);
  }
}

function _cancel(ids: any[]) {
  ids.forEach((rid) => _reject(rid, 'canceled'));
}

function _waiting() {
  return _.find(pending, () => true) !== undefined;
}

// --------------------------------------------------------------------------
// --- Server Command Queue
// --------------------------------------------------------------------------

function _flush() {
  if (!flushing) {
    flushing = setImmediate(() => {
      flushing = undefined;
      _send();
    });
  }
}

function _poll() {
  if (!polling) {
    const delay = (config && config.polling) || 50;
    polling = setTimeout(() => {
      polling = undefined;
      _send();
    }, delay);
  }
}

function _send() {
  // when busy, will be eventually re-triggered
  if (!busy) {
    const cmds = queueCmd;
    if (!cmds.length && _waiting()) cmds.push('POLL');
    if (cmds.length) {
      const ids = queueIds;
      queueCmd = [];
      queueIds = [];
      if (socket) {
        busy = true;
        socket.send(cmds)
          .then(() => socket.receive().then((resp: any) => _receive(resp)))
          .catch(() => _cancel(ids))
          .finally(() => { busy = false; Dome.emit(STATUS); });
      } else {
        _cancel(ids)
      }
    } else {
      // No pending command nor pending response
      rqid = 0;
    }
    Dome.emit(STATUS);
  }
}

function _receive(resp: any) {
  try {
    let rid, data, err, cmd;
    const shift = () => resp.shift().toString();
    while (resp.length) {
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
          _reject(rid, 'killed');
          break;
        case 'ERROR':
          rid = shift();
          err = shift();
          _reject(rid, err);
          break;
        case 'REJECTED':
          rid = shift();
          _reject(rid, 'rejected');
          break;
        case 'SIGNAL':
          rid = shift();
          Dome.emit(SIGNAL + rid);
          break;
        case 'WRONG':
          err = shift();
          console.error('[Frama-C Server] ZMQ Protocol Error:', err);
          break;
        default:
          console.error('[Frama-C Server] Unknown Response:', cmd);
          resp.length = 0;
          break;
      }
    }
  } finally {
    if (queueCmd.length)
      _flush();
    else
      _poll();
  }
}

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default {
  configure, getConfig,
  getStatus, useStatus, buffer,
  getError, getPending, isRunning,
  start, stop, kill, restart, clear,
  sendGET, sendSET, sendEXEC,
  onReady, onShutdown, onActivity,
  onSignal, offSignal, useSignal,
  STATUS, READY, SHUTDOWN, STATUS_CODE
};

// --------------------------------------------------------------------------
