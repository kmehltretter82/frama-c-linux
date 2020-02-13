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
   The prefix `'frama-c-state.'` is exported as `States.STATE` in public API.
*/
export const STATE = 'frama-c.state.' ;

// --------------------------------------------------------------------------
// --- Current Project
// --------------------------------------------------------------------------

var currentProject = undefined ;

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
  currentProject = project ;
  Dome.emit(PROJECT);
}

/**
   @summary Clear Project.
   @param {Module} module - the Frama-C module
   @param {string} [project] - the project identifier, defaults to current
   @description
   Remove all projectified values for the specified project
   Emits `PROJECT`.
 */
export function clearProject(project)
{
  const theProject = project || currentProject ;
  if (theProject)
    _.unset( globalStates , [theProject] );
  Dome.emit(PROJECT);
}

// --------------------------------------------------------------------------
// --- Projectified State
// --------------------------------------------------------------------------

var globalStates = {} ;

/**
   @summary Projectified State (Custom React Hook).
   @param {string} id - the state identifier (mandatory)
   @param {string} [project] - the project identifier, defaults to current
   @return {array} `[state,setState]` for the specified project
   @description
   Returns a getter and a setter for the specified state
   in the specified or current project.
   The initial value of states is always `undefined`.

   Each state is associated to a specific event `frama-c-state.<id>` which is
   is used to notify updates. The hook also updates on `PROJECT` notifications.
 */
export function useState(id,project)
{
  const theEvent = STATE + id ;
  Dome.useUpdate( PROJECT, theEvent );
  const theProject = project || currentProject ;
  if (!theProject) return NONE;
  const thePath = [theProject,id] ;
  const theValue = _.get( globalStates, thePath );
  const setValue = (v) => {
    _.set( globalStates, thePath, v );
    Dome.emit(theEvent,v);
  };
  return [ theValue, setValue ];
}

// --------------------------------------------------------------------------

export default { useProject, setProject, clearProject, useState, PROJECT };

// --------------------------------------------------------------------------
