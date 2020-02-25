// --------------------------------------------------------------------------
// --- Frama-C States
// --------------------------------------------------------------------------

/**
    @module frama-c/states
    @description
    Manage the current Frama-C project and projectified state values.
*/

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import Server from './server' ;

/**
   @event
   @name 'frama-c.project'
   @summary Current Project Updates
   @description
   Exported as `State.PROJECT` in public API.
*/
export const PROJECT = 'frama-c.project' ;

/**
   @event
   @name 'frama-c.state.*'
   @summary State Notification Events.
   @description
   Event `'frama-c.state.<id>'` for project `<id>`.
   The prefix `'frama-c.state.'` is exported as `States.STATE` in public API.
*/
export const STATE = 'frama-c.state.' ;

// --------------------------------------------------------------------------
// --- Synchronized Current Project
// --------------------------------------------------------------------------

var currentProject = undefined ;
var states = {} ;

Server.onReady(() => {
  Server.sendGET('kernel.project.getCurrent')
    .then((current) => {
      currentProject = current.id ;
      Dome.emit(PROJECT);
    });
});

Server.onShutdown(() => {
  currentProject = undefined ;
  states = {} ;
  Dome.emit(PROJECT);
});

// --------------------------------------------------------------------------
// --- Project API
// --------------------------------------------------------------------------

/**
   @summary Current Project (Custom React Hook).
   @return {string} the current project identifier, or `undefined`.
 */
export function useProject()
{
  Dome.useUpdate(PROJECT);
  return currentProject;
}

/**
   @summary Update Current Project.
   @param {string} project - the project identifier
   @description
   Make all states switching to their projectified value.
   Emits `PROJECT`.
 */
export function setProject(project)
{
  if (Server.isRunning()) {
    Server.sendSET( 'kernel.project.setCurrent' , project );
    currentProject = project ;
    Dome.emit(PROJECT);
  }
}

// --------------------------------------------------------------------------
// --- Projectified State
// --------------------------------------------------------------------------

function getValue(id,project) {
  if (!project) return undefined;
  return _.get( states, [project,id] );
}

function setValue(id,project,value) {
  const theProject = project || currentProject ;
  if (!theProject) return ;
  _.set( states, [project,id], value );
  Dome.emit( STATE + id , value );
}

/**
   @summary Projectified State (Custom React Hook).
   @param {string} id - the state identifier (mandatory)
   @return {array} `[state,setState]` for the specified project
   @description
   Returns a getter and a setter for the specified state
   in the specified or current project.
   The initial value of states is always `undefined`.

   Each state is associated to a specific event `frama-c-state.<id>` which is
   is used to notify updates. The hook also updates on `PROJECT` notifications.
 */
export function useState(id)
{
  Dome.useUpdate( PROJECT, STATE + id );
  const project = currentProject ;
  const value = getValue(id,project);
  return [ value , (v) => setValue(id,project,v) ];
}

// --------------------------------------------------------------------------
// --- Cached GET Requests
// --------------------------------------------------------------------------

/**
   @summary Cached GET request (Custom React Hook).
   @param {string} rq - GET request name
   @param {any} [params] - GET request parameter
   @param {boolean} [cancel] - Cancel value when updating (default is `false`)
   @return {any} [result] GET reequest response (when available)
   @description
   Sends the specified GET request and returns its result.
   The request is send asynchronously and cached until any change in
   `rq`, `params`, current project or server activity.

   The result can be `undefined` when the Server is off or until
   the server response has been actually received
   (first request or `cancel=true`).
 */
export function useRequest( rq, params, cancel=false )
{
  let project = useProject();
  let [ value, setValue ] = React.useState();
  React.useEffect( () => {
    if (project) {
      if (cancel) setValue(undefined);
      Server.sendGET( rq , params ).then(setValue);
    } else {
      if (value !== undefined) setValue(undefined);
    }
  } , [ project, rq, JSON.stringify(params) ] );
  return value;
}

// --------------------------------------------------------------------------
// --- Synchronized States
// --------------------------------------------------------------------------

// shared for all projects
class SyncState {

  constructor(id) {
    this.id = id ;
    this.UPDATE = STATE + id ;
    this.signal = id + '.sig' ;
    this.get_rq = id + '.get' ;
    this.set_rq = id + '.set' ;
    this.insync = false ;
    this.value = undefined ;
    this.update = this.update.bind(this);
    this.effect = this.effect.bind(this);
    this.setValue = this.setValue.bind(this);
    Dome.on( PROJECT , this.update );
  }

  value() {
    if (!this.insync && Server.isRunning())
      this.update();
    return this.value ;
  }

  setValue(v) {
    this.insync = true ;
    this.value = v ;
    Server.sendSET( this.set_rq , v );
    Dome.emit( this.UPDATE );
  }

  update() {
    const project = currentProject ;
    this.insync = true ;
    Server.sendGET( this.get_rq ).then((v) => {
      this.value = v ;
      Dome.emit( this.UPDATE );
    });
  }

}

// --------------------------------------------------------------------------
// --- Synchronized States Registry
// --------------------------------------------------------------------------

var syncStates = {} ;

function getSyncState(id) {
  let s = syncStates[id] ;
  if (!s) s = syncStates[id] = new SyncState(id);
  return s ;
}

Server.onShutdown(() => syncStates = {});

// --------------------------------------------------------------------------
// --- Synchronized State Hooks
// --------------------------------------------------------------------------

/**
   @summary Use Synchronized State (Custom React Hook).
   @parameter {string} id - name of the server state
   @return {Array} `[ value , setValue ]` of the synchronized state
   @description
   Synchronization with some (projectified) server state:
   - sends a `<id>.get` request to obtain the current value of the state;
   - sends a `<id>.set` request to update the value of the state;
   - listens to `<id>.sig` signal to stay in sync with server updates.
 */
export function useSyncState(id)
{
  let s = getSyncState(id) ;
  Dome.useUpdate( PROJECT, s.UPDATE );
  Server.useSignal( s.signal , s.update );
  return [ s.value() , s.setValue ];
}

/**
   @summary Use Synchronized Value (Custom React Hook).
   @parameter {string} id - name of the server state
   @return {any} current `value` of the state
   @description
   Synchronization with some (projectified) server value:
   - sends a `<id>.get` request to obtain the current value of the state;
   - listens to `<id>.sig` signal to stay in sync with server updates.
*/
export function useSyncValue(id)
{
  let s = getSyncState(id) ;
  Dome.useUpdate( s.update );
  Server.useSignal( s.signal , s.update );
  return s.value();
}

// --------------------------------------------------------------------------
// --- Synchronized Arrays
// --------------------------------------------------------------------------

// one per project
class SyncArray
{

  constructor(id) {
    this.UPDATE = STATE + id ;
    this.signal = id + '.sig' ;
    this.fetch_rq = id + '.fetch' ;
    this.reload_rq = id + '.reload' ;
    this.index = {} ;
    this.insync = false ;
    this.fetch = this.fetch.bind(this);
    this.reload = this.reload.bind(this);
  }

  getItems() {
    if (!this.insync && Server.isRunning()) this.fetch();
    return this.index;
  }

  isEmpty() {
    return _.find( this.index , () => true ) !== undefined ;
  }

  fetch() {
    this.insync = true ;
    Server.sendGET( this.fetch_rq, 50 )
      .then(({
        reload=false, removed=[], updated=[], pending=0
      }) => {
        let reloaded = false ;
        if (reload) {
          reloaded = this.isEmpty();
          this.index = {};
        }
        removed.forEach((key) => {
          delete this.index[key];
        });
        updated.forEach((item) => {
          this.index[item.key] = item;
        });
        if (reloaded || removed.length || updated.length)
          Dome.emit( this.UPDATE );
        if (pending>0) {
          this.fetch();
        }
      });
  }

  reload() {
    Server.sendSET( this.reload_rq );
    this.index = {};
    this.insync = false ;
    Dome.emit( this.UPDATE );
  }

}

// --------------------------------------------------------------------------
// --- Synchronized Arrays Registry
// --------------------------------------------------------------------------

var syncArrays = {} ; // Model by project & id

function getSyncArray(id) {
  const path = [ currentProject || '' , id ] ;
  let a = _.get( syncArrays , path );
  if (!a) {
    a = new SyncArray(id);
    _.set( syncArrays , path , a );
  }
  return a;
}

Server.onShutdown(() => syncArrays = {});

// --------------------------------------------------------------------------
// --- Synchronized Array Hooks
// --------------------------------------------------------------------------

/**
   @summary Force a Synchronized Array to Reload.
   @description
   Sends the `<id>.reload` request to the server for
   triggering a complete array reload.
 */
export function reloadArray(id)
{
  getSyncArray(id).reload();
}

/**
   @summary Use Synchronized Array (Custom React Hook).
   @parameter {string} id - name of the server array
   @return {object} items indexed by their identifiers
   @description
   Synchronization with some (projectified) server array:
   - sends `<id>.fetch` requests to obtain the updated entries;
   - listens to `<id>.sig` signal to stay in sync with server updates.
 */
export function useSyncArray(id)
{
  let a = getSyncArray(id);
  Dome.useUpdate( PROJECT, a.UPDATE );
  Server.useSignal( a.signal, a.fetch );
  return a.getItems() ;
}

// --------------------------------------------------------------------------

export default {
  useProject, setProject,
  useState,
  useSyncState,
  useSyncValue,
  useSyncArray,
  reloadArray,
  PROJECT, STATE
};

// --------------------------------------------------------------------------
