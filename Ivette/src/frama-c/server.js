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
import Zmq from 'zeromq' ;

// --------------------------------------------------------------------------
// --- Events
// --------------------------------------------------------------------------

/**
   @event
   @summary Server Status Notification Event
   @description
   Event `'frama-c.server`.
*/
export const SERVER = 'frama-c.server' ;

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
var config;    // Server process config
var sent;      // Characters sent
var recv;      // Characters received
var started;   // Date of Server activity start
var process;   // Cumulated Server processing time
var socket;    // ZMQ (REQ) socket
var busy;      // ZMQ socket is busy
var killer;    // killer timeout

// --------------------------------------------------------------------------
// --- Server Console
// --------------------------------------------------------------------------

export const console = new Buffer({ maxlines: 200 });

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
   @summary Server Statistics.
   @return {object} stats (see above)
   @description
   The returned object has the following properties:
   - `pending` : number of pending requests;
   - `requests` : number of issued requests;
   - `time` : ellapsed time of server activity, in milliseconds.
   - `sent` : number of UTF-8 chars sent to server;
   - `recv` : number of UTF-8 chars received from server;
   - `rate` : number of requests per milliseconds.
*/
export function getStats() {
  const pending = _.reduce( pending , (n,_) => n+1, 0 );
  const requests = rqid - pending ;
  const time = process + (started ? Date.now() - started : 0 );
  const rate = process ? requests / process : 0 ;
  return {
    pending, requests, sent, recv, rate, time
  };
}

// --------------------------------------------------------------------------
// --- Status Update
// --------------------------------------------------------------------------

function _status(s,err) {
  if (s !== status || err) {
    status = s;
    error = err;
    Dome.emit(SERVER);
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

   You can use `server.start` instead of `() => server.start()`.
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

   You can use `server.stop` instead of `() => server.stop()`.
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

   You can use `server.kill` instead of `() => server.kill()`.
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
    console.clear();
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
   @param {string} [config.sockaddr] - Server socket (default: `ipc:///.frama-c.socket.io`)
   @param {number} [config.timeout] - Shutdown timeout before server is hard killed, in milliseconds (default: 300ms)
   @param {number} [config.polling] - Server polling period, in milliseconds (default: 50ms)
   @param {string} [config.logout] - Process stdout log file (default: `undefined`)
   @param {string} [config.logerr] - Process stderr log file (default: `undefined`)
*/
export function configure( cfg )
{
  config = cfg;
}

// --------------------------------------------------------------------------
// --- Low-level Launching
// --------------------------------------------------------------------------

async function _launch() {
  _reset();
  if (!config) throw('Frama-C Server not configured');
  let { env, cwd, command='frama-c', params, sockaddr, logout, logerr } = config;
  if (!cwd) cwd = System.getWorkingDir();
  if (!sockaddr) sockaddr = System.join( cwd , '.frama-c.socket.io' );
  logout = logout && System.join( cwd, logout );
  logerr = logerr && System.join( cwd, logerr );
  params = params.concat('-then','-server-zmq','ipc://' + sockaddr );
  let options = {
    cwd,
    stdout: { path: logout, pipe: true },
    stderr: { path: logerr, pipe: true },
    env
  };
  // Launch Process
  const process = await System.spawn( command, params, options );
  const logging = console.append ;
  const kill = kill ;
  console.clear();
  process = process ;
  process.stdout.on('data', logging );
  process.stderr.on('data', logging );
  process.on('close', (status) => {
    logging('Exit',status,'\n');
    _close(status);
  });
  // Connect to Server
  socket = new Zmq.Request();
  busy = false ;
  await socket.bind(sockaddr).catch(kill);
}

// --------------------------------------------------------------------------
// --- Low-level Killing
// --------------------------------------------------------------------------

function _reset() {
  rqid = 0;
  sent = 0;
  recv = 0;
  started = undefined;
  process = undefined;
  started = undefined;
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
    const process = process ;
    if (process) {
      const timeout = (config && config.timeout) || 300 ;
      killer = setTimeout( () => process.kill() , timeout );
    }
  }
}

function _close(status) {
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
  if (status) {
    _status(FAILED,'Exit Status ' + status);
  } else {
    _status(IDLE);
  }
}

// --------------------------------------------------------------------------
// --- Request Queue
// --------------------------------------------------------------------------

export function sendGET( rq, params ) { return _sendRequest( 'GET' , rq , params ); }
export function sendSET( rq, params ) { return _sendRequest( 'SET' , rq , params ); }
export function sendEXEC( rq, params ) { return _sendRequest( 'EXEC' , rq , params ); }

function _sendRequest( kind, rq , params ) {
  if (!isRunning()) return Promise.reject('Server not running');
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

function  _cancel(ids) {
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
    const cmd = queue_cmd ;
    if (!cmd.length && _waiting()) cmd.push('POLL');
    if (!cmd.length) {
      const ids = queue_ids ;
      queue_cmd = [];
      queue_ids = [];
      const socket = socket ;
      if (socket) {
        if (!started) started = Date.now() ;
        busy = true ;
        sent = cmd.reduce( (s,p) => s + p.length , sent);
        socket.send( cmd )
          .then(() => socket.receive().then((resp) => _receive(resp)))
          .catch(() => _cancel(ids))
          .finally(() => busy = false);
      } else
        _cancel(ids);
    } else {
      const started = started ;
      if (started) {
        const stopped = Date.now();
        process += stopped - started ;
        started = undefined ;
      }
    }
  }
}

function _receive(resp) {
  try {
    recv = resp.reduce( (s,p) => s + p.length , recv);
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
  configure, console,
  getStatus, getError, getStats, isRunning,
  start, stop, kill, restart, clear,
  sendGET, sendSET, sendEXEC,
  IDLE,STARTED,RUNNING,KILLING,RESTART,FAILED
};

// --------------------------------------------------------------------------
