// --------------------------------------------------------------------------
// ---  Plugin Base Class
// --------------------------------------------------------------------------

/** @module @ivette/plugins */

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import EventEmitter from 'events' ;

/**
    @event
    @description
    Triggered when a module is asked for killing its pending jobs.
*/
export const KILL = 'ivette.kill' ;

/**
   @event
   @description
   Triggered when a module enters in locked state
*/
export const LOCK = 'ivette.lock' ;

/**
    @event
    @description
    Triggered when a module is back to unlocked state
*/
export const UNLOCK = 'ivette.unlock' ;

/**
    @event
    @description
    Triggered when a plugin has been configured
*/
export const CONFIG = 'ivette.config' ;

/**
    @event
    @description
    Triggered when a plugin has been updated
*/
export const UPDATE = 'ivette.update' ;

/**
   @summary Base class for Module instances.
   @property {string} id - Module identifier
   @property {string} [label] - Module display name
   @property {string} [title] - Module short description
   @property {object} config - Module configuration object
   @property {string} session - Module session directory
   @description
   Each Ivette module is associated to a global object maintaining its internal state.
   A `Plugin` is a class responsible for creating and managing the internal state of a module.
   It is also responsible for rendering the module main view, its toolbar and sidebar items,
   and configuration fields.
*/
export class Module extends EventEmitter {

  constructor() {
    super();
    this.config = {} ;
    let _lock = { sem: 0 } ;
    let _LOCKED = () => _lock.sem > 0 ;
    let _LOCK = () => {
      if (_lock.sem == 0) this.emit(LOCK);
      _lock.sem++;
    } ;
    let _UNLOCK = () => {
      _lock.sem--;
      if (_lock.sem == 0) this.emit(UNLOCK);
      if (_lock.sem < 0) {
        console.warn(`[Ivette:${this.id}] unbalanced lock/unlock`,this.id);
        _lock.sem = 0 ;
      }
    } ;
    let _SYNCHRO = (p,k) => {
      _LOCK() ;
      if (k) this.once(KILL,k);
      p.finally(() => {
        if (k) this.off(KILL,k);
        _UNLOCK();
      });
      return p;
    } ;
    this.lock = _LOCK ;
    this.unlock = _UNLOCK ;
    this.locked = _LOCKED ;
    this.synchronize = _SYNCHRO ;
    this.renderMain = this.renderMain.bind(this);
    this.renderConfig = this.renderConfig.bind(this);
  }

  // --------------------------------------------------------------------------
  // --- Locking
  // --------------------------------------------------------------------------

  /**
     @summary Lock the plugin.
     @description
     Prevents the module from being re-configured.
     Nested calls to `lock/unlock` shall be well balanced.
     It is preferrable to use `this.synchronize()` instead.
     Emits the signal `'ivette.lock'` unless already locked.
  */
  lock() {} // privately defined by constructor

  /**
     @summary Unlock the plugin.
     @description
     Cancel the last `lock()` call effect.
     Nested calls to `lock/unlock` shall be well balanced.
     It is preferrable to use `this.synchronize()` instead.
     Emits the signal `'ivette.unlock'` when actually unlocked.
  */
  unlock() {} // privately defined by constructor

  /** Whether the module is currenly locked or not.
      @return {boolean} the locked status of the module. */
  locked() {} // privately defined by constructor

  /**
     @summary Lock the module until a promise is pending.
     @param {Promise} job - the promise to lock on
     @param {function} kill - a callback to kill the job
     @return {Promise} the job, for chaining
     @description
     Locks the module and wait for the promise to terminate
     (normally or with an error) before unlocking.  The callback is triggered
     if the module is asked to be killed while the job is still running.
  */
  synchronize() {} // privately defined by constructor

  /**
     @summary Promise awaiting until unlocked.
     @return {Promise} awaiting promise
     @description
     The returned promise is resolved once the
     plugin is unlocked. It is immediately resolved
     if not locked.
  */
  wait() {
    if ( !this.locked() ) {
      return Promise.resolved();
    } else {
      return new Promise((resolve,reject) => this.once(UNLOCK,resolve));
    }
  }

  /**
     @summary Interrupts pending tasks.
     @description
     Emits the `'ivette.kill'` signal.
     Any currently running job shall be interrupted,
     and the module shall eventually be unlocked.
     @return {Promise} a promise resolved once unlocked
  */
  kill() {
    this.emit(KILL);
    return this.wait();
  }

  // --------------------------------------------------------------------------
  // --- Render
  // --------------------------------------------------------------------------

  /**
     @summary Emits the `@ivette.plugins.UPDATE` event.
   */
  update() {
    this.emit(UPDATE);
  }

  /**
     @summary Main view for the plugin.
     @return {React.Children} the main view for the module
     @description
     See also the '@ivette/views' for defining sidebars and toolbars.
  */
  renderMain() {
    return null;
  }

  /**
     @summary Configuration view for the plugin.
     @return {React.Children} form fields for configuring the plugin
  */
  renderConfig() {
    return null;
  }

}

// --------------------------------------------------------------------------
// --- Plugin Factory
// --------------------------------------------------------------------------

/**
   @typedef PLUGIN
   @summary Plugin Specification
   @property {string} id - plugin identifier
   @property {string} [label] - display name
   @property {string} [title] - short description
   @property {function} [initializer] - module initializer
   @property {React.Element} [mainView] - main view
   @property {React.Element} [configView] - configuration view
   @description

   Properties for [registerPlugin](module-@ivette.html#registerPlugin)
   specification.

   The `initializer` function, when specified,
   is invoked once on each plugin instance.
   The initializer function can be written as follows:
   - `initializer() { ... this.XXX ... }`
   - `initializer: function() { ... this.XXX ... }`
   - `initializer: (module) => { ... module.XXX ... }`

   Typical usage of `initializer` is to initialize specific module properties
   and register static callbacks on module events like `CONFIG` and `KILL`.
*/

export function Factory(spec) {
  const { id, label, title, mainView, configView, initializer } = spec;

  class Plugin extends Module {
    constructor() {
      super();
      initializer && initializer.apply(this, [this]);
    }
    renderMain() { return mainView; }
    renderConfig() { return configView; }
  };
  Plugin.id = id;
  Plugin.label = label;
  Plugin.title = title;

  return Plugin;
}

// --------------------------------------------------------------------------

export default { Module, Factory, KILL, LOCK, UNLOCK, CONFIG, UPDATE } ;

// --------------------------------------------------------------------------
