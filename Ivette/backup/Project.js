// --------------------------------------------------------------------------
// --- Current State of Project
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import Dialogs from 'dome/dialogs' ;
import System from 'dome/system' ;
import Ivette from '@ivette' ;
import { Module } from '@ivette/plugins' ;

// --------------------------------------------------------------------------
// --- Global State
// --------------------------------------------------------------------------

/*
  - 'frame': currently displayed frame in main window
  - 'current': currently selected module object
  - 'configure.module': original configured module
  - 'configure.value': edited module properties
  - 'configure.error': edited module errors
  - 'configure.copied': true if the the target is a fresh copy from another module
  - 'configure.modified': true if the value has been edited
 */

const project = new Dome.State({ frame: 'home' });

export const setState = project.setState ;
export const useState = project.useState ;

const mkSetFrame = (frame) => () => project.setState({frame});
export const setHome = mkSetFrame('home');
export const setDisplay = mkSetFrame('display');
export const setConfigure = mkSetFrame('configure');

// --------------------------------------------------------------------------
// --- Module Helpers
// --------------------------------------------------------------------------

export function initConfigValue( module )
{
  let { id, label, descr } = module ;
  let config = _.cloneDeep( module.config );
  return { id, label, descr, config };
}

export function setConfiguring( module, onClose )
{
  if (module instanceof Module) {
    let value = initConfigValue( module );
    setState({
      frame: 'configure',
      configure: Object.assign( { onClose }, { value, module } )
    });
  } else
    console.err( 'Not a plugin instance' , module );
}

// --------------------------------------------------------------------------
// --- Module Helpers
// --------------------------------------------------------------------------

export function lookupProject() {

  let argv = System.argv();
  let commandProject = Ivette.lookupProject( argv[0] );
  if (commandProject) return commandProject ;

  let previousProject = Ivette.lookupProject( Dome.getGlobalSetting('ivette.working.project') );
  if (previousProject) return previousProject ;

  let workingProject = Ivette.lookupProject( System.getWorking() );
  if (workingProject) return workingProject ;

  return undefined ;
}

export function loadProject( dir )
{
  if (!dir) return ;
  Dome.setGlobalSetting('ivette.working.project',dir);
  let setup = Ivette.loadProject( dir );
  setup.then( (errors) => errors && errors.length && Dialogs.showMessageBox({
    kind: 'error',
    message: 'Error(s) when loading project:\n' + errors.join('\n'),
    buttons: [{ label: 'Ok' }]
  })).finally(Dome.update);
}

// --------------------------------------------------------------------------
// --- Exports Default
// --------------------------------------------------------------------------

export default {
  useState, setState, setHome, setConfigure, setDisplay,
  setConfiguring, initConfigValue,
  lookupProject, loadProject
};

// --------------------------------------------------------------------------
