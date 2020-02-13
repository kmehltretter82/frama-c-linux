// --------------------------------------------------------------------------
// --- Frama-C Server
// --------------------------------------------------------------------------

/**
    @module frama-c/server
    @description
    Manage the current Frama-C server/client interface
*/

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import System from 'dome/system' ;
import { Buffer } from 'dome/text/buffers' ;
import { Request } from 'zeromq' ;

// --------------------------------------------------------------------------
// --- Events
// --------------------------------------------------------------------------

/**
   @event
   @name 'frama-c.server.status'
   @summary Server Status Notification Event
   @description
   This event is emitted whenever the server status changes.

   Exported as `Server.STATUS' in public API.
*/
export const STATUS = 'frama-c.server.status' ;

/**
   @event
   @name 'frama-c.server.ready'
   @summary Server is actually started and running.
   @description
   This event is emitted when ther server _enters_ the `RUNNING` state.
   It is now ready to handle requests.

   Exported as `Server.READY' in public API.
*/
export const READY = 'frama-c.server.ready' ;

/**
   @event
   @name 'frama-c.server.shutdown'
   @summary Server Status Notification Event
   @description
   This event is emitted when ther server _leaves_ the `RUNNING` state.
   It is no more able to handle requests until re-start.

   Exported as `Server.SHUTDOWN' in public API.
*/
export const SHUTDOWN = 'frama-c.server.shutdown' ;

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/**
   @typedef STATUS
   @summary Server Status Codes.
   @description
- `IDLE` Server paused
- `STARTED` Frama-C command launched
- `RUNNING` Server ready
- `KILLING` Server shutdown, waiting for exit
- `RESTART` Server shutdown, will reboot on exit
- `FAILED` Server halted on error
 */

export const IDLE = 'IDLE' ;
export const STARTED = 'STARTED' ; // Command started
export const RUNNING = 'RUNNING' ; // Server connected
export const KILLING = 'KILLING' ; // Waiting for halt
export const RESTART = 'RESTART' ; // Restart when halt
export const FAILED  = 'FAILED'  ; // Error issued

// --------------------------------------------------------------------------
// --- Server Global State
// --------------------------------------------------------------------------

var status = IDLE;
var error;     // process error
var rqid;      // Request ID
var pending;   // Pending promise callbacks
var queue_cmd; // Queue of server commands to be sent
var queue_ids; // Waiting request ids to be sent
var polling;   // Timeout Polling timer
var flushed;   // Immediate Flushed timer
var config;    // Server config
var process;   // Server process
var socket;    // ZMQ (REQ) socket
var busy;      // ZMQ socket is busy
var killer;    // killer timeout

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

export const buffer = new Buffer({ maxlines: 200 });

// --------------------------------------------------------------------------
// --- Server Status
// --------------------------------------------------------------------------

/**
   @summary Current Server `STATUS`.
   @return {STATUS} the current server status
   @description
   See [STATUS](module-frama-c_server.html#~STATUS) code definitions.
*/
export function getStatus() { return status; }

/** Return `FAILED` status message. */
export function getError() { return error; }

/**
   @summary Frama-C Server is running and ready to handle requests.
   @return {boolean} status is `RUNNING`.
*/
export function isRunning() { return status === RUNNING; }

/**
   @summary Number of requests still pending.
   @return {number} pending requests
*/
export function getPending() {
  return _.reduce( pending , (_,n) => n+1, 0 );
}

/**
   @summary Register callback on READY event.
   @param {function} callback - invoked when the server enters RUNNING status
 */
export function onReady(callback) { Dome.on(READY,callback); }

/**
   @summary Register callback on SHUTDOWN event.
   @param {function} callback - invoked when the server enters SHUTDOWN status
 */
export function onShutdown(callback) { Dome.on(SHUTDOWN,callback); }

// --------------------------------------------------------------------------
// --- Status Update
// --------------------------------------------------------------------------

function _status(new_s,err) {
  if (Dome.DEVEL && err) console.error('[Server]',err);
  if (new_s !== status || err) {
    let old_s = status ;
    status = new_s;
    error = err ? err.toString() : undefined ;
    Dome.emit(STATUS);
    if (old_s === RUNNING) Dome.emit(SHUTDOWN);
    if (new_s === RUNNING) Dome.emit(READY);
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Start)
// --------------------------------------------------------------------------

/**
   @summary Start the Server.
   @description
   If the server is started or running, this is a no-op.
   If the server is being shutdown, it will reboot.
   Otherwise, the Frama-C Server is spawned.
*/
export function start() {
  switch(status) {
  case IDLE:
  case FAILED:
    _status(STARTED);
    _launch()
      .then(() => _status(RUNNING))
      .catch((err) => _status(FAILED,err));
    return;
  case KILLING:
    _status(RESTART);
    return;
  case STARTED:
  case RUNNING:
  case RESTART:
  default:
    return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Stop)
// --------------------------------------------------------------------------

/**
   @summary Stop the Server.
   @description
   If the server is starting, it is hard killed.
   If the server is running, it is shutdown gracefully.
   When the server is shutting down, restart is canceled.
   Otherwise, this is a no-op.
*/
export function stop() {
  switch(status) {
  case STARTED:
    _kill();
    _status(KILLING);
    return;
  case RUNNING:
    _shutdown();
    _status(KILLING);
    return;
  case RESTART:
    _status(KILLING);
    return;
  case IDLE:
  case FAILED:
  case KILLING:
  default:
    return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Kill)
// --------------------------------------------------------------------------

/**
   @summary Terminate the Server.
   @description
   If the server is starting or running or shutting down,
   it is hard killed and restart is canceled.
   Otherwize, this is no-op.

   This function is automatically called when the `module` emits the `KILL` signal.
*/
export function kill() {
  switch(status) {
  case STARTED:
  case RUNNING:
  case KILLING:
  case RESTART:
    _kill();
    _status(KILLING);
    return;
  case IDLE:
  case FAILED:
  default:
    return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Restart)
// --------------------------------------------------------------------------

/**
   @summary Re-start the Server.
   @description
   If paused, simply start the Server.
   When running, try to gracefully shutdown the Server,
   and finally schedule a reboot on exit.
*/
export function restart() {
  switch(status) {
  case IDLE:
  case FAILED:
    start();
    return;
  case RUNNING:
    _shutdown();
    // Fall Through
  case KILLING:
    _status(RESTART);
    return;
  case STARTED:
  case RESTART:
  default:
    return;
  }
}

// --------------------------------------------------------------------------
// --- Server Control (Reset)
// --------------------------------------------------------------------------

/**
   @summary Acknowledge `FAILED` status.
   @description
   When not running, clear the console and reset any error flag.
   Otherwised, do nothing.
*/
export function clear() {
  switch(status) {
  case FAILED:
    _status(IDLE);
    // Fall Through
  case IDLE:
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

/**
   @summary Configure the Server.
   @param {object} config - Server Configuration
   @param {Object} [config.env] - Process environment variables (default: `undefined`)
   @param {string} [config.cwd] - Working directory (default: current)
   @param {string} [config.command] - Server command (default: `frama-c`)
   @param {Array.<string>} [config.params] - Additional server arguments (default: empty)
   @param {string} [config.sockaddr] - Server socket (default: `ipc:///.frama-c.<pid>.io`)
   @param {number} [config.timeout] - Shutdown timeout before server is hard killed, in milliseconds (default: 300ms)
   @param {number} [config.polling] - Server polling period, in milliseconds (default: 50ms)
   @param {string} [config.logout] - Process stdout log file (default: `undefined`)
   @param {string} [config.logerr] - Process stderr log file (default: `undefined`)
*/
export function configure( cfg )
{
  config = cfg || {} ;
}

// --------------------------------------------------------------------------
// --- Low-level Launching
// --------------------------------------------------------------------------

async function _launch() {
  _reset();
  if (!config) throw('Frama-C Server not configured');
  let { env, cwd, command='frama-c', params=[], sockaddr, logout, logerr } = config;

  buffer.clear();
  buffer.append('$',command);
  let size = params.reduce((n,p) => n + p.length , 0);
  if (size < 40)
    buffer.append('',...params);
  else
    params.forEach((argv) => {
      if (argv.startsWith('-') || argv.endsWith('.c') || argv.endsWith('.i') || argv.endsWith('.h'))
        buffer.append('\n    ');
      buffer.append(' ');
      buffer.append(argv);
    });
  buffer.append('\n');

  if (!cwd) cwd = System.getWorkingDir();
  if (!sockaddr) {
    let socketfile = System.join(cwd,'.frama-c.' + System.getPID() + '.io');
    System.atExit(() => System.remove(socketfile));
    sockaddr = 'ipc://' + socketfile ;
  }
  logout = logout && System.join( cwd, logout );
  logerr = logerr && System.join( cwd, logerr );
  params = params.concat('-then','-server-zmq',sockaddr );
  let options = {
    cwd,
    stdout: { path: logout, pipe: true },
    stderr: { path: logerr, pipe: true },
    env
  };
  // Launch Process
  const process = await System.spawn( command, params, options );
  const kill = () => process.kill() ;
  const logger = (text) => {
    buffer.append(text);
    if (0 <= text.indexOf('\n'))
      buffer.scroll();
  };
  process.stdout.on('data', logger );
  process.stderr.on('data', logger );
  process.on('error', (err) => {
    buffer.append('Error:',err,'\n');
    _close(err);
  });
  process.on('exit', (status,signal) => {
    signal && buffer.log('Signal:',signal);
    status && buffer.log('Exit:',status);
    _close(signal || status);
  });
  // Connect to Server
  socket = new Request();
  busy = false ;
  socket.connect(sockaddr);
}

// --------------------------------------------------------------------------
// --- Low-level Killing
// --------------------------------------------------------------------------

function _reset() {
  rqid = 0;
  process = undefined;
  queue_cmd = [];
  queue_ids = [];
  _.forEach( pending , ({ reject }) => reject('shutdown') );
  pending = {};
  if (flushed) clearImmediate(flushed);
  flushed = undefined;
  if (polling) clearTimeout(polling);
  polling = undefined;
}

function _kill() {
  _reset();
  if (killer) clearTimeout(killer);
  if (process) process.kill();
}

function _shutdown() {
  _reset();
  queue_cmd.push('SHUTDOWN');
  _flush();
  if (!killer) {
    if (process) {
      const timeout = (config && config.timeout) || 300 ;
      killer = setTimeout( () => process.kill() , timeout );
    }
  }
}

function _close(error) {
  _reset();
  if (killer) {
    clearTimeout( killer );
    killer = undefined ;
  }
  if (socket) {
    socket.close();
    socket = undefined ;
    busy = false ;
  }
  if (process) {
    process.kill();
    process = undefined ;
  }
  if (error) {
    _status(FAILED,error);
  } else {
    _status(IDLE);
  }
}

// --------------------------------------------------------------------------
// --- Request Queue
// --------------------------------------------------------------------------

/**
   @summary Send a GET request to the server.
   @param {string} rq - the request identifier
   @param {object} params - request parameters
   @return {Promise<object>} the promised request results
   @description
   You may _kill_ the request before its normal termination by
   invoking `kill()` on the returned promised.
 */
export function sendGET( rq, params ) { return _sendRequest( 'GET' , rq , params ); }

/**
   @summary Send a SET request to the server.
   @param {string} rq - the request identifier
   @param {object} params - request parameters
   @return {Promise<object>} the promised request results
   @description
   You may _kill_ the request before its normal termination by
   invoking `kill()` on the returned promised.
 */
export function sendSET( rq, params ) { return _sendRequest( 'SET' , rq , params ); }

/**
   @summary Send an EXEC request to the server.
   @param {string} rq - the request identifier
   @param {object} params - request parameters
   @return {Promise<object>} the promised request results
   @description
   You may _kill_ the request before its normal termination by
   invoking `kill()` on the returned promised.
 */
export function sendEXEC( rq, params ) { return _sendRequest( 'EXEC' , rq , params ); }

// --------------------------------------------------------------------------
// --- Request Management
// --------------------------------------------------------------------------

function _sendRequest( kind, rq , params=null ) {
  if (!isRunning()) return Promise.reject('Server not running');
  if (!rq) return Promise.reject('Undefined request');
  const rid = 'RQ.' + rqid++;
  const data = JSON.stringify(params);
  const promise = new Promise((resolve,reject) => {
    pending[rid] = { resolve, reject };
    queue_cmd.push(kind,rid,rq,data);
    queue_ids.push(rid);
  });
  promise.kill = () => {
    if (socket && pending[rid]) {
      queue_cmd.push('KILL',rid);
      _flush();
    }
  };
  _flush();
  return promise;
}

function _resolve(id,result) {
  let promise = pending[id];
  if (promise) {
    delete pending[id];
    promise.resolve(result);
  }
}

function _reject(id,error) {
  let promise = pending[id];
  if (promise) {
    delete pending[id];
    promise.reject(error);
  }
}

function _cancel(ids) {
  ids.forEach((rid) => _reject(rid,'canceled'));
}

function _waiting() {
  return _.find( pending , () => true ) !== undefined ;
}

// --------------------------------------------------------------------------
// --- Server Command Queue
// --------------------------------------------------------------------------

function _flush() {
  if (!flushed) {
    flushed = setImmediate(() => {
      flushed = undefined;
      _send();
    });
  }
}

function _poll() {
  if (!polling) {
    let delay = (config && config.polling) || 50 ;
    polling = setTimeout(() => {
      polling = false;
      _send();
    }, delay);
  }
}

function _send() {
  // when busy, will be eventually re-triggered
  if (!busy) {
    const cmds = queue_cmd ;
    if (!cmds.length && _waiting()) cmds.push('POLL');
    if (cmds.length) {
      const ids = queue_ids ;
      queue_cmd = [];
      queue_ids = [];
      if (socket) {
        busy = true ;
        socket.send( cmds )
          .then(() => socket.receive().then((resp) => _receive(resp)))
          .catch(() => _cancel(ids))
          .finally(() => { busy = false ; Dome.emit(STATUS); });
      } else
        _cancel(ids);
      Dome.emit(STATUS);
    }
  }
}

function _receive(resp) {
  try {
    var rid,data,err,cmd;
    const shift = () => resp.shift().toString();
    while( resp.length ) {
      cmd = shift();
      switch( cmd ) {
      case 'NONE':
        break;
      case 'DATA':
        rid = shift();
        data = shift();
        _resolve(rid,data);
        break;
      case 'KILLED':
        rid = shift();
        _reject(rid,'killed');
        break;
      case 'ERROR':
        rid = shift();
        err = shift();
        _reject(rid,err);
        break;
      case 'REJECTED':
        rid = shift();
        _reject(rid,'rejected');
        break;
      case 'WRONG':
        err = shift();
        console.error('[Frama-C Server] ZMQ Protocol Error:',err);
        break;
      case 'NONE':
        break;
      default:
        console.error('[Frama-C Server] Unknown Response:',cmd);
        resp.length = 0;
        break;
      }
    }
  } finally {
    if (queue_cmd.length)
      _flush();
    else
      _poll();
  }
}

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default {
  configure, buffer,
  getStatus, getError, getPending, isRunning,
  start, stop, kill, restart, clear,
  sendGET, sendSET, sendEXEC,
  onReady, onShutdown,
  STATUS,READY,SHUTDOWN,
  IDLE,STARTED,RUNNING,KILLING,RESTART,FAILED
};

// --------------------------------------------------------------------------
