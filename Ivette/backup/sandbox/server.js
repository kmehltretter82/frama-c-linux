// --------------------------------------------------------------------------
// --- Global State
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import Dome from 'dome' ;
import System from 'dome/system' ;
import { Request } from 'zeromq' ;

// --------------------------------------------------------------------------
// --- Frama-C Server
// --------------------------------------------------------------------------

const url = 'ipc:///tmp/fc.io' ;

var stable = true ;
var server = null ;

export function isStopped() { return stable && server === null; }
export function isRunning() { return stable && server !== null; }

export function stopServer() {
  if (server) {
    stable = false;
    server.kill();
    Dome.update();
  }
}

export function startServer() {
  if (stable && !server) {
    stable = false ;
    System.spawn
    ( 'frama-c',
      [
        '-server-zmq', url,
        '-server-debug', 1
      ]
    ).then((process) => {
      stable = true ;
      server = process ;
      startSocket();
      process.stdout.on('data',(msg) => {console.log(msg); Dome.emit('console',msg)});
      process.stderr.on('data',(msg) => {console.log(msg); Dome.emit('console',msg)});
        process.on('close',(status) => {
        console.log(`Frama-C exit with status ${status}\n`);
        Dome.emit('console',`Frama-C exit with status ${status}\n`);
        stable = true ;
        server = null ;
        stopSocket();
        Dome.update();
      });
      Dome.update();
    }).catch((err) => {
      stable = true ;
      server = null ;
      console.log('Error: ' + err + '\n');
      Dome.emit('console','Error: ' + err + '\n');
      Dome.update();
    });
    Dome.update();
  }
}

// // --------------------------------------------------------------------------
// // --- Frama-C Socket
// // --------------------------------------------------------------------------

var socket = null;
var queue_cmd = [];
var queue_ids = [];
var waiting = false;
var promises = {};
var pending = 0;
var kid = 0;

export function getPending() { return pending; }

export function killPending() {
  _.forEach(promises,( _data , rid ) => {
    queue_cmd.push( 'KILL' );
    queue_cmd.push( rid );
  });
  flushQueue();
}

function startSocket() {
    if (socket) stopSocket();
    socket = new Request();
    socket.connect(url);
    console.log("socket connected\n");
    // Dome.emit('server',true);
}

function stopSocket() {
  if (socket) {
    _.forEach(promises,( { reject } ) => reject('socket closed') );
    socket.close();
    waiting = false;
    socket = null;
    // Dome.emit('server',false);
  }
}

function sendRequest( kind , request , params = null , more ) {
    console.log("send request\n");
  return new Promise((resolve,reject) => {
    if (!socket) reject('socket closed');
    try {
      const rid = 'RQ' + kid++ ;
      const data = JSON.stringify(params);
      pending++;
      promises[rid] = { resolve , reject } ;
      queue_ids.push(rid);
      queue_cmd.push(kind);
      queue_cmd.push(rid);
      queue_cmd.push(request);
      queue_cmd.push(data);
      if (!more) flushQueue();
    } catch(err) {
      reject(err);
    }
  });
}

export function sendGET( request, params, more ) { return sendRequest('GET',request,params,more); }
export function sendSET( request, params, more ) { return sendRequest('SET',request,params,more); }
export function sendEXEC( request, params, more ) { return sendRequest('EXEC',request,params,more); }

function flushQueue() {
    if (!waiting && (queue_cmd.length > 0 || pending > 0)) {
        console.log("flushQeue\n");
    const cmd = queue_cmd.length > 0 ? queue_cmd : 'POLL' ;
    const ids = queue_ids ;
    queue_ids = [];
    queue_cmd = [];
    waiting = true ;
    socket.send( cmd )
      .then(()  => {console.log("query sent\n"); socket.receive().then(receiveResponse)})
      .catch((err) => {
        console.log("error: " + err + "\n")
        waiting = false;
        ids.forEach( (id) => rejectRequest(id,err) );
      });
  }
}

function receiveResponse( commands ) {
  console.log("response received\n");
  waiting = false;
  while( commands.length ) {
    var rid,data,err;
    const cmd = commands.shift();
    switch( cmd.toString() ) {
    case 'NONE':
      break;
    case 'DATA':
      rid = commands.shift();
      data = commands.shift();
      resolveRequest(rid,data);
      break;
    case 'ERROR':
      rid = commands.shift();
      err = commands.shift();
      rejectRequest(rid,err);
      break;
    case 'KILLED':
      rid = commands.shift();
      rejectRequest(rid,'killed');
      break;
    case 'REJECTED':
      rid = commands.shift();
      rejectRequest(rid,'rejected');
      break;
    case 'WRONG':
      err = commands.shift();
      console.log('SERVER-ERROR:' + err);
      // Dome.warn('SERVER-ERROR:',err);
      break;
    default:
      // Dome.warn('SERVER-UNKNOWN-RESPONSE:',cmd,commands);
      console.log(`SERVER-UNKNOWN-RESPONSE: (${cmd})\n`,commands);
      commands.length = 0;
      break;
    }
  }
  flushQueue();
}

function rejectRequest(rid,err) {
  const entry = promises[rid];
  if (entry) {
    delete promises[rid];
    pending--;
    entry.reject(err);
  }
}

function resolveRequest(rid,data) {
  const entry = promises[rid];
  if (entry) {
    delete promises[rid];
    pending--;
    try {
      entry.resolve(JSON.parse(data));
    } catch(err) {
      entry.reject(err);
    }
  }
}

// --------------------------------------------------------------------------

System.atExit(() => {
  stopServer();
  stopSocket();
});

export default {
  isStopped, isRunning,
  startServer, stopServer,
  sendSET, sendGET, sendEXEC,
  getPending, killPending
};

// --------------------------------------------------------------------------
