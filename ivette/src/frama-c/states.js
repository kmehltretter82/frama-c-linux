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
var states = {};
var stateDefaults = {};

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
  return _.get( states, [project,id], stateDefaults[id] );
}

function setValue(id,project,value) {
  if (!project) return ;
  _.set( states, [project,id], value );
  Dome.emit( STATE + id , value );
}

/**
   @summary Define the default state value.
   @param {string} id - the state identifier (mandatory)
   @param {any} value - the new default state
 */
export function setStateDefault(id,value)
{
  stateDefaults[id] = value;
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
   @param {object} [options] - Special values
   @param {any} [options.offline] - Returned value when off-line
   @param {any} [options.pending] - Returned value when pending response
   @param {any} [options.error] - Returned value on request error
   @return {any} [result] GET request response (when available)
   @description
   Sends the specified GET request and returns its result.
   The request is send asynchronously and cached until any change in
   `rq`, `params`, current project or server activity.

   Default values for various situations can be defined in the options parameter,
   which is `undefined` unless specified, or `null` to keep the current value.
   For instance `{ pending: null }` will return `undefined` when off-line and in case of errors,
   but will keep the last received value until a new one is actually received.
 */
export function useRequest( rq, params, options={} )
{
  const project = useProject();
  const [ value, setValue ] = React.useState( options.offline );
  React.useEffect( () => {
    if (project) {
      const pending = options.prending ;
      if (pending !== null) setValue(pending);
      Server.sendGET( rq , params )
        .then(setValue)
        .catch(err => {
          if (Dome.DEVEL) console.warn(`[Server] use request '${rq}':`,err);
          const error = options.error ;
          if (error !== null) setValue(error);
        });
    } else {
      const v = options.offline ;
      if (value !== v) setValue(v);
    }
  } , [ project, rq, JSON.stringify(params) ] );
  return value;
}

// --------------------------------------------------------------------------
// --- Dictionaries
// --------------------------------------------------------------------------

/**
   @summary Cached GET request (Custom React Hook).
   @param {string} rq - GET request name
   @param {any} [params] - GET request parameter (default `'null'`)
   @param {object} [options] - Dictionary options
   @param {boolean} [options.key] - The property to index an item (default `'name'`)
   @param {boolean} [options.offline] - Keep the dictionary when offline (default `true`)
   @param {boolean} [options.pending] - Keep the dictionary when pending (default `true`)
   @param {boolean} [options.error] - Keep the dictionary on error (default `false`)
   @param {function} [options.filter] - Only index items satisfying the filter (default `undefined`)
   @return {object} [result] GET request response indexed by key
   @description
   Sends the specified GET request and returns its returned collection indexed by the provided key.
   Items in the collection that do have the key are not indexed.
*/
export function useDictionary( rq, params=null, options={} )
{
  const { offline=true, pending=true, error=false, key='name', filter } = options ;
  const tags = useRequest( rq, params, {
    offline: offline ? null : undefined,
    pending: pending ? null : undefined,
    error: error ? null : undefined
  });
  const dict = React.useMemo( () => {
    const d = {};
    _.forEach( tags, tg => {
      let k = tg[key];
      if (k && (!filter || filter(tg))) d[k] = tg;
    });
    return d;
  } , [ tags, filter ]);
  return dict;
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
        if (reloaded || removed.length || updated.length) {
          this.index = Object.assign( {}, this.index );
          Dome.emit( this.UPDATE );
        }
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
// --- Selection
// --------------------------------------------------------------------------

const SELECTION = 'kernel.selection' ;

setStateDefault( SELECTION , {} );

/**
   @summary Current selection state.
   @return {array} `[selection,update]` for the current selection
   @description
   The selection is an object with many independant fields.
   You update it by providing only some fields, the other ones being kept unchanged,
   like the `setState()` behaviour of React components.
 */
export function useSelection()
{
  const [ state, setState ] = useState( SELECTION );
  return [ state, (upd) => setState(Object.assign( {}, state, upd )) ];
}

// --------------------------------------------------------------------------

export default {
  useProject,
  setProject,
  setStateDefault,
  useState,
  useSyncState,
  useSyncValue,
  useSyncArray,
  reloadArray,
  useRequest,
  useDictionary,
  useSelection,
  PROJECT, STATE
};

// --------------------------------------------------------------------------
