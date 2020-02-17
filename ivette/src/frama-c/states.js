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

const NONE = [ undefined, () => undefined ]; // No-state

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
var globalStates = {} ;
var globalSync = {} ;

Server.onReady(() => {
  Server.sendGET('kernel.project.getCurrent')
    .then((current) => {
      currentProject = current.id ;
      Dome.emit(PROJECT);
    });
});

Server.onShutdown(() => {
  currentProject = undefined ;
  globalStates = {} ;
  globalSync = {} ;
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
  return _.get( globalStates, [project,id] );
}

function setValue(id,project,value) {
  const theProject = project || currentProject ;
  if (!theProject) return ;
  _.set( globalStates, [project,id], value );
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
// --- Synchronized States
// --------------------------------------------------------------------------

class Synchro {

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

const synchros = {} ;
function synchro(id) {
  let s = synchros[id] ;
  if (!s) s = synchros[id] = new Synchro(id);
  return s ;
}

Server.onReady(() => _.forEach( synchros , (s) => {
  if (!s.insync) s.update();
}));

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
  let s = synchro(id) ;
  Dome.useUpdate( s.UPDATE );
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
  let s = synchro(id) ;
  Dome.useUpdate( s.update );
  React.useEffect( s.effect );
  return s.value();
}

// --------------------------------------------------------------------------

export default {
  useProject, setProject,
  useState,
  useSyncState,
  useSyncValue,
  PROJECT, STATE
};

// --------------------------------------------------------------------------
