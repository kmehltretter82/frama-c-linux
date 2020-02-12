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
// --- Server Utilities
// --------------------------------------------------------------------------
/*
const SERVER_LOG = '-server-log' ;
const SERVER_NO_LOG = '-server-no-log' ;
const SERVER_OPT = '-server-zmq' ;
const SERVER_DEF = '-server-zmq=' ;
const SERVER_URL = '.frama-c.socket.io' ;

const getZmqLog = (params) => params.find((opt) => (
  opt === SERVER_LOG || opt === SERVER_NO_LOG
));

const getZmqURL = (params) => {
  let def = params.findIndex((opt) => opt.startsWith(SERVER_DEF));
  if (def) {
    let quote = def[ SERVER_DEF.length ];
    return ( quote === "'" || quote === '"' )
      ? def.slice( SERVER_DEF.length + 1 , -1 )
      : def.slice( SERVER_DEF.length );
  }
  let pos = params.findIndex((opt) => opt.startsWith(SERVER_OPT));
  if (pos) return params[pos+1];
  return undefined ;
};
*/
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
// --- Server Class
// --------------------------------------------------------------------------

/**
   @summary Frama-C Server Interface.
   @description
   This class is responsible for running a Frama-C server
   and communicate with it.
   The server automatically locks the module when running
   and listen to module KILL events.

   The server shall be property configured before being started.
   It does _not_ use configuration from `module.config` on its own ;
   you shall configure it by using `server.configure()`.
 */
export class Server {

  constructor() {
    this.status = IDLE ;
    this.console = new Buffer({ maxlines: 200 });
    this._reset();
    this.stop = this.stop.bind(this);
    this.kill = this.kill.bind(this);
    this.start = this.start.bind(this);
    this.restart = this.restart.bind(this);
    this.clearFailed = this.clearFailed.bind(this);
  }

  // --------------------------------------------------------------------------

  // CLIENT STATE:
  // this.rqid      // Request ID
  // this.sent      // Characters sent
  // this.recv      // Characters received
  // this.started   // Date of Server activity start
  // this.process   // Cumulated Server processing time
  // this.pending   // Pending promise callbacks
  // this.queue_cmd // Queue of server commands to be sent
  // this.queue_ids // Waiting request ids to be sent
  // this.polling   // Polling scheduled

  // SERVER STATE:
  // this.config: server process config
  // this.process: dome child process
  // this.socket: ZMQ (REQ) socket
  // this.busy: ZMQ socket is busy
  // this.error: process error
  // this.killer: killer timeout

  // SERVER CONFIG:
  // See this.configure()

  // --------------------------------------------------------------------------
  // --- Server Status
  // --------------------------------------------------------------------------

  /** Return `FAILED` status message. */
  getError() { return this.error; }

  /**
     @summary Current Server `STATUS`.
     @return {STATUS} the current server status
     @description
     See [STATUS](module-frama-c_server.html#~STATUS) code definitions.
  */
  getStatus() { return this.status; }
  _status(s,err) {
    if (s !== this.status || err) {
      this.status = s;
      this.error = err;
      this.module.emit(SERVER);
    }
  }

  /**
     @summary Frama-C Server is running and ready to handle requests.
     @return {boolean} status is `RUNNING`.
   */
  isRunning() { return this.status === RUNNING; }

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
  getStats() {
    const pending = _.reduce( this.pending , (n,_) => n+1, 0 );
    const requests = this.rqid - pending ;
    const process = this.process ;
    const started = this.started ;
    const sent = this.sent ;
    const recv = this.recv ;
    const time = process + (started ? Date.now() - started : 0 );
    const rate = process ? requests / process : 0 ;
    return {
      pending, requests, sent, recv, rate, time
    };
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
  start() {
    switch(this.status) {
    case IDLE:
    case FAILED:
      this._status(STARTED);
      this._launch()
        .then(() => this._status(RUNNING))
        .catch((err) => this._status(FAILED,err));
      return;
    case KILLING:
      this._status(RESTART);
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
  stop() {
    switch(this.status) {
    case STARTED:
      this._kill();
      this._status(KILLING);
      return;
    case RUNNING:
      this._shutdown();
      this._status(KILLING);
      return;
    case RESTART:
      this._status(KILLING);
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
  kill() {
    switch(this.status) {
    case STARTED:
    case RUNNING:
    case KILLING:
    case RESTART:
      this._kill();
      this._status(KILLING);
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
  restart() {
    switch(this.status) {
    case IDLE:
    case FAILED:
      this.start();
      return;
    case RUNNING:
      this._shutdown();
      // Fall Through
    case KILLING:
      this._status(RESTART);
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
     Simply go back to `IDLE` status when `FAILED`.
     Otherwised, do nothing.
  */
  clearFailed() {
    if (this.status === FAILED)
      this._status(IDLE);
  }

  // --------------------------------------------------------------------------
  // --- Server Configure
  // --------------------------------------------------------------------------

  /**
     @summary Configure the Server.
     @param {object} config - Server Configuration
     @param {string} [config.command] - Server command (default: `frama-c`)
     @param {Array.<string>} [config.params] - Server arguments (default: `-server-zmq .frama-c.socket.io`)
     @param {string} [config.sockaddr] - Server socket name (default: `.frama-c.socket.io`)
     @param {string} [config.logout] - Process stdout log file (default: `undefined`)
     @param {string} [config.logerr] - Process stderr log file (default: `undefined`)
     @param {Object} [config.env] - Process environment variables (default: `undefined`)
  */
  configure( config )
  {
    if (!config)
      this.config =
      {
        command: 'frama-c',
        params: ['-server-zmq', '.frama-c.socket.io'],
        sockaddr: '.frama-c.socket.io'
      }
    else
      this.config = config;
  }

  // --------------------------------------------------------------------------
  // --- Low-level Launching
  // --------------------------------------------------------------------------

  async _launch() {
    this._reset();
    if (!this.config) throw('Frama-C Server not configured');
    let { env, command, params, sockaddr, logout, logerr } = this.config;
    sockaddr = System.join( this.module.session, sockaddr );
    logout = logout && System.join( this.module.session, logout );
    logerr = logerr && System.join( this.module.session, logerr );
    let options = {
      cwd: this.module.session,
      stdout: { path: logout, pipe: true },
      stderr: { path: logerr, pipe: true },
      env
    };
    // Launch Process
    const process = await System.spawn( command, params, options );
    const logging = this.console.append ;
    const kill = this.kill ;
    this.console.clear();
    this.module.lock();
    this.module.on(KILL,kill);
    this.process = process ;
    process.stdout.on('data', logging );
    process.stderr.on('data', logging );
    process.on('close', (status) => {
      this.module.off(KILL,kill);
      this.module.unlock();
      logging('Exit',status,'\n');
      this._close(status);
    });
    // Connect to Server
    this.socket = new Zmq.Request();
    this.busy = false ;
    await this.socket.bind(addr).catch(kill);
  }

  // --------------------------------------------------------------------------
  // --- Low-level Killing
  // --------------------------------------------------------------------------

  _reset() {
    this.rqid = 0;
    this.sent = 0;
    this.recv = 0;
    this.time = 0;
    this.process = 0;
    this.started = undefined;
    this.queue_cmd = [];
    this.queue_ids = [];
    const pending = this.pending ;
    this.pending = {};
    _.forEach( pending , ({ reject }) => reject('shutdown') );
    if (this.flushed) clearImmediate(this.flushed);
    this.flushed = undefined;
    if (this.polling) clearTimeout(this.polling);
    this.polling = undefined;
  }

  _kill() {
    this._reset();
    if (this.killer) clearTimeout(this.killer);
    if (this.process) this.process.kill();
  }

  _shutdown() {
    this._reset();
    this.queue_cmd.push('SHUTDOWN');
    this._flush();
    if (!this.killer) {
      const process = this.process ;
      if (process) {
        const timeout = (this.config && this.config.timeout) || 300 ;
        this.killer = setTimeout( () => process.kill() , timeout );
      }
    }
  }

  _close(status) {
    this._reset();
    if (this.killer) {
      clearTimeout( this.killer );
      this.killer = undefined ;
    }
    if (this.socket) {
      this.socket.close();
      this.socket = undefined ;
      this.busy = false ;
    }
    if (this.process) {
      this.process.kill();
      this.process = undefined ;
    }
    if (status) {
      this._status(FAILED,'Exit Status ' + status);
    } else {
      this._status(IDLE);
    }
  }

  // --------------------------------------------------------------------------
  // --- Request Queue
  // --------------------------------------------------------------------------

  sendGET( rq, params ) { return this._sendRequest( 'GET' , rq , params ); }
  sendSET( rq, params ) { return this._sendRequest( 'SET' , rq , params ); }
  sendEXEC( rq, params ) { return this._sendRequest( 'EXEC' , rq , params ); }

  _sendRequest( kind, rq , params ) {
    if (!this.isRunning()) return Promise.reject('Server not running');
    const rid = 'RQ.' + this.rqid++;
    const data = JSON.stringify(params);
    const promise = new Promise((resolve,reject) => {
      this.pending[rid] = { resolve, reject };
      this.queue_cmd.push(kind,rid,rq,data);
      this.queue_ids.push(rid);
    });
    promise.kill = () => {
      if (this.socket && this.pending[rid]) {
        this.queue_cmd.push('KILL',rid);
        this._flush();
      }
    };
    this._flush();
    return promise;
  }

  _resolve(id,result) {
    let promise = this.pending[id];
    if (promise) {
      delete this.pending[id];
      promise.resolve(result);
    }
  }

  _reject(id,error) {
    let promise = this.pending[id];
    if (promise) {
      delete this.pending[id];
      promise.reject(error);
    }
  }

  _cancel(ids) {
    ids.forEach((rid) => this._reject(rid,'canceled'));
  }

  _waiting() {
    return _.find( this.resolve , () => true ) !== undefined ;
  }

  // --------------------------------------------------------------------------
  // --- Server Command Queue
  // --------------------------------------------------------------------------

  _flush() {
    if (!this.flushed) {
      this.flushed = setImmediate(() => {
        this.flushed = undefined;
        this._send();
      });
    }
  }

  _poll() {
    if (!this.polling) {
      let timeout = (this.config && this.config.polling) || 50 ;
      this.polling = setTimeout(() => {
        this.polling = false;
        this._send();
      }, timeout);
    }
  }

  _send() {
    // when busy, will be eventually re-triggered
    if (!this.busy) {
      const cmd = this.queue_cmd ;
      if (!cmd.length && this._waiting()) cmd.push('POLL');
      if (!cmd.length) {
        const ids = this.queue_ids ;
        this.queue_cmd = [];
        this.queue_ids = [];
        const socket = this.socket ;
        if (socket) {
          if (!this.started) this.started = Date.now() ;
          this.busy = true ;
          this.sent = cmd.reduce( (s,p) => s + p.length , this.sent);
          socket.send( cmd )
            .then(() => socket.receive().then((resp) => this._receive(resp)))
            .catch(() => this._cancel(ids))
            .finally(() => this.busy = false);
        } else
          this._cancel(ids);
      } else {
        const started = this.started ;
        if (started) {
          const stopped = Date.now();
          this.process += stopped - started ;
          this.started = undefined ;
        }
      }
    }
  }

  _receive(resp) {
    try {
      this.recv = resp.reduce( (s,p) => s + p.length , this.recv);
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
          this._resolve(rid,data);
          break;
        case 'KILLED':
          rid = shift();
          this._reject(rid,'killed');
          break;
        case 'ERROR':
          rid = shift();
          err = shift();
          this._reject(rid,err);
          break;
        case 'REJECTED':
          rid = shift();
          this._reject(rid,'rejected');
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
      if (this.queue_cmd.length)
        this._flush();
      else
        this._poll();
    }
  }

}

// --------------------------------------------------------------------------
// --- Exports
// --------------------------------------------------------------------------

export default {
  Server,
  IDLE,STARTED,RUNNING,KILLING,RESTART,FAILED
};

// --------------------------------------------------------------------------
