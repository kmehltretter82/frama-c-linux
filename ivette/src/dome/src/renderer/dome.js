/**
   @packageDocumentation
   @module dome(renderer)
   @description

   ## Dome Application (Renderer Process)

   This modules manages your main application window
   and its interaction with the main process.

   Example:

   ```typescript
   // File 'src/renderer/index.js':
   import Application from './Application.js' ;
   Dome.setContent( Application );
   ```
 */

import _ from 'lodash' ;
import React from 'react';
import ReactDOM from 'react-dom';
import { AppContainer } from 'react-hot-loader' ;
import { remote , ipcRenderer } from 'electron';
import { EventEmitter } from 'events' ;
import SYS , * as System from 'dome/system' ;
import './style.css' ;

// --------------------------------------------------------------------------
// --- Context
// --------------------------------------------------------------------------

// main window focus
var focus = true ;

function setContextAppNode()
{
  const node = document.getElementById('app');
  if (node) {
    node.className =
      'dome-container dome-platform-' + System.platform +
      ( focus ? ' dome-window-active' : ' dome-window-inactive' ) ;
  }
  return node;
}

// --------------------------------------------------------------------------
// --- Helpers
// --------------------------------------------------------------------------

/** @summary Development mode flag.
    @description
    Configured to be `'true'` when in development mode
*/
export const DEVEL = System.DEVEL ;

/** @summary System platform.
    @description
    Same as `platform` from `dome/system` */
export const platform = System.platform ;

// --------------------------------------------------------------------------
// --- Application Emitter
// --------------------------------------------------------------------------

/** @summary Application Emitter.
    @description
    Can be used as a basic _Flux_ dispatcher. */
export const emitter = new EventEmitter();

/** Same as `emitter.on` */
export function on(evt,job) { emitter.on(evt,job); }

/** Same as `emitter.off` */
export function off(evt,job) { emitter.off(evt,job); }

/** Same as `emitter.emit` */
export function emit(evt,...args) { emitter.emit(evt,...args); }

{
  emitter.setMaxListeners(250);
}

// --------------------------------------------------------------------------
// --- Application Events
// --------------------------------------------------------------------------

/** @event 'dome.update'
    @description
    Convenient pre-defined events for triggering a global re-render.
    See also [Dome.onUpdate](#.onUpdate), [Dome.update](#.update) methods and
    the [Dome.useUpdate](#.useUpdate) hook.
*/

/** @event 'dome.reload'
    @description
    Triggered when the application has been loaded or re-loaded
    See also [Dome.onReload](#.onReload).
*/

/** @event 'dome.command'
    @param {Array.<string>} argv - command line arguments
    @param {string} wdir - working directory
    @description
    Triggered when the command line argument has been received, and when
    the application is re-loaded (in development mode).

    See also [Dome.onCommand](#.onCommand).
*/

/**
   @summary Emits the `dome.update` event.
*/
export function update() { emitter.emit('dome.update'); }

/**
   @summary Update event handler.
   @param {function} cb - invoked on update events.
   @description
   Register a callback on [dome.update](#~event:'dome.update') event.
*/
export function onUpdate(job) { emitter.on('dome.update',job); }

/**
   @summary Update event handler.
   @param {function} cb - invoked on reload events.
   @description
   Register a callback on [dome.reload](#~event:'dome.reload') event.
*/
export function onReload(job) { emitter.on('dome.reload',job); }

/** @summary Command-line event handler.
    @param {function} cb - invoked with `cb(argv,wdir)`
    @description
Register a callback on [dome.command](#~event:'dome.reload') event,
emitted by the `Main` process when the application instance is launched.

See also:
 - [[useCommand]]
 - `System.getArguments`
 - `System.getWorkingDir`
*/
export function onCommand(job) { emitter.on('dome.command',job); }

ipcRenderer.on('dome.ipc.reload',() => emitter.emit('dome.reload'));
ipcRenderer.on('dome.ipc.command', (_event,argv,wdir) => {
  SYS.SET_COMMAND(argv,wdir);
  emitter.emit('dome.command',argv,wdir);
});

// --------------------------------------------------------------------------
// --- Main-Process Communication
// --------------------------------------------------------------------------

// --------------------------------------------------------------------------
// --- Window Management
// --------------------------------------------------------------------------

export function isApplicationWindow()
{
  return process.argv.includes( SYS.WINDOW_APPLICATION_ARGV );
}

export function isPreferencesWindow()
{
  return process.argv.includes( SYS.WINDOW_PREFERENCES_ARGV );
}

// --------------------------------------------------------------------------
// --- Window Title
// --------------------------------------------------------------------------

export function setModified( modified )
{
  ipcRenderer.send('dome.ipc.window.modified',modified);
}

export function setTitle( title )
{
  ipcRenderer.send('dome.ipc.window.title',title);
}

// --------------------------------------------------------------------------
// --- Main Content
// --------------------------------------------------------------------------

/**
   @summary Defines the user's main window content.
   @param {React.Component} Component - to be rendered in the main window
   @description
   Binds the component to the main window.

   <strong>Notes:</strong> a `<Component/>` instance is generated and rendered in the `#app`
   window element. Its class name is set to `dome-platform-<platform>` with
   the `<platform>` set to the `Dome.platform` value. This class name can be used
   as a CSS selector for platform-dependent styling.
*/
export function setApplicationWindow( Component )
{
  if (isApplicationWindow()) {
    syncSettings();
    const appNode = setContextAppNode();
    ReactDOM.render( <AppContainer><Component/></AppContainer> , appNode );
  }
}

// --------------------------------------------------------------------------
// --- Settings Window
// --------------------------------------------------------------------------

/**
   @summary Defines the user's preferences window content.
   @param {React.Component} Component - to be rendered in the settings window
   @description
   Binds the component to the settings window.

   <strong>Notes:</strong> a `<Component/>` instance is generated and rendered in the `#app`
   window element. Its class name is set to `dome-platform-<platform>` with
   the `<platform>` set to the `Dome.platform` value. This class name can be used
   as a CSS selector for platform-dependent styling.
*/
export function setPreferencesWindow( Component )
{
  if (isPreferencesWindow()) {
    syncSettings();
    const appNode = setContextAppNode();
    ReactDOM.render( <AppContainer><Component/></AppContainer> , appNode );
  }
}

// --------------------------------------------------------------------------
// --- MenuBar Management
// --------------------------------------------------------------------------

const customItemCallbacks = {} ;

/**
   @summary Create a new custom menu in the menu bar.
   @param {string} label - the menu title (shall be unique)
   @description
   This function can be triggered at any time, and will eventually trigger
   an update of the whole application menubar.

   It is also possible to call this function from the main process.
*/
export function addMenu( label ) { ipcRenderer.send( 'dome.ipc.menu.addmenu' , label ); }

/**
   @summary Insert a new custom item in a menu.
   @param {object} spec - the menu-item specification
   @description
The menu-item shall be specified by using the following fields:
 - `menu` (`string`, _required_) : the label of the menu to insert the item in;
   can be a custom menu, or one of the predefined `'File'`, `'Edit'` or `'View'` menus.
 - `id` (`string|number`, _required_) : the item identifier;
   shall be unique among the entire menu-bar.
 - `type` (`string`, _optional_) : one of `'normal'`, `'separator'`, `'checkbox'` or `'radio'`.
 - `label` (`string`, _optional_) : the item label.
 - `visible` (`boolean`, _optional_, default is `true`).
 - `enabled` (`boolean`, _optional_, default is `true`).
 - `checked` (`boolean`, _optional_, for `type:'checkbox'` and `type:'radio'` only, default is `false`).
 - `key` (`string`, _optional_) : a keyboard shortcut for menu-item.
 - `onClick` (`function`, _optional_) : an optional callback.

These options (except `menu` and `id`) can be modified later on by using the [setMenuItem](#.setMenuItem) function.

When clicked, the menu-item will also trigger a `'dome.menu.clicked'` event on the entire application (both process)
with the corresponding `id`.

Key short cuts shall be specified with the following codes:
 - `"Cmd+<Key>"` for command (MacOS) or control (Linux) key
 - `"Alt+<Key>"` for command+option (MacOS) or alt (Linux) key
 - `"Meta+<Key>"` for command+shift (MacOS) or control+alt (Linux) key

Alternatively, more precise keybord shortcuts can be specified with the `'accelerator'` option,
which follows the same encoding that menu-item specifications from Electron.

The `addMenu` function can be triggered at any time, and will eventually trigger
an update of the whole application menubar.
It is also possible to call this function from the main process.

*/
export function addMenuItem( spec )
{
  if (!spec.id && spec.type !== 'separator') {
    console.error('[Dome] Missing menu-item identifier',spec);
    return;
  }
  const { onClick , ...options } = spec ;
  if ( onClick ) customItemCallbacks[ spec.id ] = onClick ;
  ipcRenderer.send( 'dome.ipc.menu.addmenuitem' , options );
}

/**
   @summary Update properties of an existing menu-item.
   @param {object} options - the menu-item specification to update
   @description
   Options must follow the specification of the [addMenuItem](#.addMenuItem) function.
   Option `id` must specify the identifier of the menu item to update.
   The menu and item positions can _not_ be modified.
   If an `onClick` callback is specified, it will _replace_ the previous one.
   You shall specify `null` to remove the previously registered callback
   (`undefined` callback is ignored).

   This function can be triggered at any time, and will possibly trigger
   an update of the whole application menubar if the properties
   can not be changed dynamically in Electron.

   It is also possible to call this function from the main process.
   When specified, the item callback is only invoked in the process which
   specify it. To register callbacks in other process,
   you shall listen to the `'dome.menu.clicked'` event.
 */
export function setMenuItem( options ) {
  if (!options.id) {
    console.error('[Dome] Missing menu-item identifier',options);
    return;
  }
  const { onClick , ...updates } = options ;
  if (onClick !== undefined) {
    if (onClick) customItemCallbacks[options.id] = onClick ;
    else delete customItemCallbacks[options.id] ;
  }
  ipcRenderer.send( 'dome.ipc.menu.setmenuitem', updates );
}

/** @event 'dome.menu.clicked'
    @description Emitted with the clicked menu-item identifier */

ipcRenderer.on('dome.ipc.menu.clicked',(id) => {
  const callback = customItemCallbacks[id] ;
  callback && callback();
});

// --------------------------------------------------------------------------
// --- Context Menus
// --------------------------------------------------------------------------

/**
   @summary Popup a contextual menu.
   @param {item[]} items - the array of menu items
   @param {function} [callback] - an optional callback
   @description
Each menu item is specified by an object with the following fields:
 - `id` (`string|number`, _optional_) : the item identifier.
 - `label` (`string`, _optional_) : the item label.
 - `enabled` (`boolean`, _optional_, default is `true`).
 - `display` (`boolean`, _optional_, default is `true`).
 - `checked` (`boolean`, _optional_, default is `undefined`).
 - `onClick` (`function`, _optional_) : callback on item selection.

Items can be separated by inserting a `'separator'` constant string
in the array. Item identifier and label default to each others. Alternatively,
an item can be specified by a single string that will be used for both
its label and identifier. Undefined or null items are allowed (and skipped).

The menu is displayed at the current mouse location.
The callback is called with the selected item identifier or label.
If the menu popup is canceled by the user, the callback is called with `undefined`.

@example
let myPopup = (_evt) => Dome.popupMenu([ …items… ],(id) => … );
<div onRightClick={myPopup}>...</div>

*/
export function popupMenu( items, callback )
{
  const { Menu , MenuItem } = remote ;
  const menu = new Menu();
  var selected = undefined ;
  var kid = 0 ;
  items.forEach((item) => {
    if (item === 'separator')
      menu.append(new MenuItem({ type:'separator' }));
    else if (item)
    {
      const { display=true, enabled, checked } = item ;
      if (display) {
        const label = item.label || '#'+(++kid) ;
        const id = item.id || label ;
        const click = () => {
          selected = id ;
          item.onClick && item.onClick();
        };
        const type = checked !== undefined ? 'checkbox' : 'normal' ;
        menu.append(new MenuItem({ label, enabled, type, checked, click }));
      }
    }
  });
  const job = callback ? () => callback( selected ) : undefined ;
  menu.popup({window: remote.getCurrentWindow(), callback:job });
}

// --------------------------------------------------------------------------
// --- Settings
// --------------------------------------------------------------------------

var globals = {} ;
var globalPatches = {} ;

var settings = {} ;
var settingsPatches = {} ;

// initial values => synchronized event
function syncSettings() {
  const fullSettings = ipcRenderer.sendSync('dome.ipc.settings.sync');
  globals = fullSettings.globals ;
  settings = fullSettings.settings ;
}

const readSetting = ( local, key, defaultValue ) => {
  const value = _.get( local ? settings : globals , key );
  return value === undefined ? defaultValue : value ;
};

const writeSetting = ( local, key, value ) => {
  if (key) {
    const theValue = value===undefined ? null : value ;
    const store = local ? settings : globals ;
    const patches = local ? settingsPatches : globalPatches ;
    _.set( store, key, theValue );
    _.set( patches,  key, theValue );
    emitter.emit('dome.settings');
    if (local) {
      if (DEVEL) fireSaveSettings();
    } else {
      fireSaveGlobals();
    }
  }
};

const fireSaveSettings = _.debounce(
  () => {
    if (!_.isEmpty(settingsPatches)) {
      ipcRenderer.send( 'dome.ipc.settings.window', settingsPatches ) ;
      settingsPatches = {} ;
    }
  }, 100
);

const fireSaveGlobals = _.debounce(
  () => {
    if (!_.isEmpty(globalPatches)) {
      ipcRenderer.send( 'dome.ipc.settings.global', globalPatches ) ;
      globalPatches = {} ;
    }
  }, 100
);

ipcRenderer.on('dome.ipc.closing', (_evt) => {
  fireSaveSettings();
  fireSaveSettings.flush();
  fireSaveGlobals();
  fireSaveGlobals.flush();
  System.doExit();
});

/** @event 'dome.settings'
    @description Emitted when the settings have been updated. */

/** @event 'dome.defaults'
    @description Emitted when the settings have been reset to default. */

ipcRenderer.on('dome.ipc.settings.defaults',(sender) => {
  fireSaveSettings.cancel();
  fireSaveGlobals.cancel();
  settingsPatches = {};
  globalPatches = {};
  settings = {};
  globals = {};
  emitter.emit('dome.defaults');
  emitter.emit('dome.settings');
});

ipcRenderer.on('dome.ipc.settings.update',(sender,patches) => {
  // Don't cancel local updates
  _.merge( globals , patches , globalPatches );
  emitter.emit('dome.settings');
});

/**
    @summary Get value from local window (persistent) settings.
    @param {string} [key] -  User's Setting Key (`'dome.*'` are reserved keys)
    @param {any} [defaultValue] - default value if the key is not present
    @return {any} associated value of object or `undefined`.
    @description
    This settings are local to the current window, but persistently
    saved in the user's home directory.<br/>
    For global application settings, use `getGlobal()` instead.
*/
export function getWindowSetting( key, defaultValue ) {
  return key ? readSetting( true, key , defaultValue ) : defaultValue ;
}

/** @summary Set value into local window (persistent) settings.
    @param {string} [key] to store the data
    @param {any} value associated value or object
    @description
    This settings are local to the current window, but persistently
    saved in the user's home directory.<br/>
    For global application settings, use `setGlobal()` instead.
*/
export function setWindowSetting( key , value ) {
  key && writeSetting( true, key, value );
}

/**
    @summary Get value from application (persistent) settings.
    @param {string} key User's Setting Key (`'dome.*'` are reserved keys)
    @param {any} [defaultValue] - default value if the key is not present
    @return {any} associated value of object or `undefined`.
    @description
    These settings are global to the application and persistently
    saved in the user's home directory.<br/>
    For local window settings, use `get()` instead.
*/
export function getGlobalSetting( key, defaultValue ) {
  return key ? readSetting( false, key , defaultValue ) : defaultValue ;
}

/** @summary Set value into application (persistent) settings.
    @param {string} key to store the data
    @param {any} value associated value or object
    @description
    These settings are global to the current window, but persistently
    saved in the user's home directory. Updated values are broadcasted
    in batch to all other windows, which in turn receive a `'dome.settings'`
    event for synchronizing.<br/>
    For local window settings, use `set()` instead.
*/
export function setGlobalSetting( key , value ) {
  writeSetting( false, key, value );
}

// --------------------------------------------------------------------------
// --- Focus Management
// --------------------------------------------------------------------------

/** Current focus state of the main window. */
export function isFocused() { return focus; }

/**
    @event 'dome.focus'
    @param {boolean} state - updated focus state
    @description Emitted when the application gain or loses focus.
*/
ipcRenderer.on('dome.ipc.focus',(sender,value) => {
  focus = value;
  setContextAppNode();
  emitter.emit('dome.focus',value);
});

// --------------------------------------------------------------------------
// --- Web Navigation
// --------------------------------------------------------------------------

/**
    @event 'dome.href'
    @param {string} href - internal `<a href=...>` target
    @description
    Emitted when the user clicks on a local `<a href=...>`.
    URL with an `http://` protocole are opened externally
    by the user's default browser.
*/
ipcRenderer.on('dome.ipc.href',(href) => emitter.emit('dome.href',href));

// --------------------------------------------------------------------------
// --- Function Component
// --------------------------------------------------------------------------

/**
   @summary Inlined Function React Component.
   @property {function} children - render function as children
   @description
   Allows to define an inlined functional component inside JSX.
   The children function _can_ use hooks.

@example
<Render>
   {() => {
        let [ state, setState ] = React.useState();
        …
        return (<div>…</div>);
   }}
</Render>
*/
export const Render = ({children}) => {
  return children();
};

// --------------------------------------------------------------------------
// --- React Hooks
// --------------------------------------------------------------------------

/**
   @summary Hook to re-render on demand (Custom React Hook).
   @return {function} to trigger re-rendering
   @description
   Returns a callback to trigger a render on demand.
*/
export function useForceUpdate()
{
  const [tac,onTic] = React.useState();
  return () => onTic(!tac);
}

/**
   @summary Hook to re-render on Dome events (Custom React Hook).
   @param {string} [event,...] - event names (default: `'dome.update'`)
   @description
   Returns nothing.
*/
export function useUpdate(...evts)
{
  const update = useForceUpdate();
  React.useEffect(() => {
    const trigger = () => setImmediate(update);
    if (evts.length == 0) evts.push('dome.update');
    evts.forEach((evt) => emitter.on(evt,trigger));
    return () => evts.forEach((evt) => emitter.off(evt,trigger));
  });
}

/**
   @summary Hook to register callbacks to Dome events (Custom React Hook).
   @param {string} event - Event to register on
   @param {function} callback - The callback to register
   @description
   Register the callback on event until the component is unmount.
   Do not force the component to re-render (unless the callback does).<br/>
   Returns nothing.
*/
export function useEvent(evt,callback)
{
  React.useEffect(() => {
    emitter.on(evt,callback);
    return () => emitter.off(evt,callback);
  });
}

/**
   @summary Hook to register callbacks to events (Custom React Hook).
   @param {EventEmitter} emitter - event emitter
   @param {string} event - Event to register on
   @param {function} callback - The callback to register
   @description
   Register the callback on event until the component is unmount.
   Do not force the component to re-render (unless the callback does).<br/>
   Returns nothing.
*/
export function useEmitter(emitter,evt,callback)
{
  React.useEffect(() => {
    emitter.on(evt,callback);
    return () => emitter.off(evt,callback);
  });
}

const NULL = {}; // Dummy initial value

// --------------------------------------------------------------------------
// --- Commands Hooks
// --------------------------------------------------------------------------

/**
   @summary Hook for command-line interface (Custom React Hook).
   @return {array} `[argv,wdir]` command-line arguments and working directory
   @description
   Returns the command-line arguments and working directory for the application
   instance running in the window. Automatically updated on `dome.command` events.

   See also [[onCommand]] event handler.
*/
export function useCommand() {
  useUpdate('dome.command');
  const wdir = System.getWorkingDir();
  const argv = System.getArguments();
  return [ argv , wdir ];
}

// --------------------------------------------------------------------------
// --- Settings Hooks
// --------------------------------------------------------------------------

function useSettings( local, settings, defaultValue )
{
  const [ value, setValue ] = React.useState(() => readSetting( local, settings, defaultValue ));
  React.useEffect(() => {
    if (settings) {
      let callback = () => {
        let v = readSetting( local, settings , defaultValue );
        setValue(v);
      };
      emitter.on('dome.settings',callback);
      return () => emitter.off( 'dome.settings', callback );
    } else {
      let callback = () => setValue(defaultValue);
      emitter.on('dome.defaults',callback);
      return () => emitter.off( 'dome.defaults', callback );
    }
  });
  const doUpdate = (upd) => {
    const theValue = typeof(upd)==='function' ? upd(value) : upd ;
    if (settings) writeSetting( local, settings, theValue );
    else setValue(theValue);
  };
  return [ value, doUpdate ];
}

/**
   @summary Local state with optional window settings (Custom React Hook).
   @param {string} [settings] - optional window settings to backup the value
   @param {any} [defaultValue] - the initial (and default) value
   @return {array} `[value,setValue]` of the local state
   @description
   Similar to `React.useState()` with persistent _window_ settings.
   When the settings key is undefined, it simply uses a local React state.
   Also responds to `'dome.settings'` to update the state and `'dome.defaults'`
   to restore the default value.

   The `setValue` callback accepts either a value, or a function to be applied
   on current value.
*/
export function useState( settings, defaultValue )
{
  return useSettings( true, settings, defaultValue );
}

/**
   @summary Local boolean state with optional window settings (Custom React Hook).
   @param {string} [settings] - optional window settings to backup the value
   @param {boolean} [defaultValue] - the initial value (default is `false`)
   @return {array} `[value,flipValue]` for the local state
   @description
   Same as [useState](#.useState) with a boolean value that can be set or flipped:
    - `flipValue()` change the value to its opposite;
    - `flipValue(v)` change the value to `v`.
*/
export function useSwitch( settings, defaultValue=false )
{
  const [ value, update ] = useSettings( true, settings, defaultValue );
  return [ value, v => update(v===undefined ? !value : v) ];
}

/**
   @summary Local state with global settings (Custom React Hook).
   @param {string} settings - global settings for storing the value
   @param {any} [defaultValue] - the initial and default value
   @return {array} `[value,setValue]` of the local state
   @description
   Similar to `React.useState()` with persistent _global_ settings.
   When the settings key is undefined, it simply uses a local React state.
   Also responds to `'dome.settings'` to update the state and `'dome.defaults'`
   to restore the default value.

   The `setValue` callback accepts either a value, or a function to be applied
   on current value.
*/
export function useGlobalSetting( settings, defaultValue )
{
  return useSettings( false, settings, defaultValue );
}

// --------------------------------------------------------------------------
// --- Global States
// --------------------------------------------------------------------------

/** @event 'dome.state.update'
    @description
    Notify updates within a State object.
*/

const STATE_UPDATE = 'dome.state.update' ;

/**
  @summary Global state object.
  @property {object} state - the current state properties
  @property {object} defaults - the default state properties
  @description

You may use this class as convenient way to implement global
state for your Dome application. Simply create a state `s` with `new State(defaults)`
and use `s.setState()`, `s.getState()` or `s.state` property, and `s.useState()`
custom hooks.

A state is also an event emitter that you can use to fire events, and you can use
the React custom hooks `s.useUpdate()` and `s.useEvent()`.

All above methods are bound to `this` by the constructor.

*/
export class State extends EventEmitter
{

  constructor(props) {
    super();
    // Makes this field private
    this.defaults = props ;
    this.state = Object.assign( {}, props );
    this.update = this.update.bind(this);
    this.getState = this.getState.bind(this);
    this.setState = this.setState.bind(this);
    this.clearState = this.clearState.bind(this);
    this.replaceState = this.replaceState.bind(this);
    this.useState = this.useState.bind(this);
    this.useEvent = this.useEvent.bind(this);
    this.useUpdate = this.useUpdate.bind(this);
  }

  /** Emits the `dome.state.update` event */
  update() { this.emit('dome.state.update'); }

  /** Returns the state property. */
  getState() { return this.state; }

  /** @summary Update the state with (some) properties.
      @param {object} props - the properties to be updated
      @description
      Update the state with `Object.assign`, like `setState()` on React components.
      Also fire the `'dome.update'` property on the object. */
  setState(props) {
    Object.assign( this.state, props );
    this.update();
  }

  /** @summary Replace (all) state properties.
      @description
      Replace the entire store with the new properties.
      Also fire the `'dome.update'` property on the object. */
  replaceState(props) {
    this.state = Object.assign( {}, props );
    this.update();
  }

  /** @summary Reset (all) state properties.
      @description
      Restore the entire store with the default properties.
      Also fire the `'dome.state.update'` property on the object. */
  clearState() {
    this.state = Object.assign( {}, this.defaults );
    this.update();
  }

  /** @summary Hook to use the state (custom React Hook).
      @return {array} `[state,setState]` with current object properties and
      function to update them. */
  useState() {
    let forceUpdate = useForceUpdate();
    useEmitter( this, 'dome.state.update', forceUpdate );
    return [ this.state , this.setState ];
  }

  /** @summary Hook to re-render your component on State events.
      @param {string} [event] - the event to listen to (defaults to `'dome.update'`)
  */
  useUpdate(evt = 'dome.state.update') {
    let forceUpdate = useForceUpdate();
    useEmitter( this, evt, forceUpdate );
  }

  /** @summary Hook to trigger callbacks on State events.
      @param {string} event - the event to listen to
      @param {function} callback - the callback triggered on event
  */
  useEvent(evt,callback) {
    useEmitter( this, evt, callback );
  }

}

// --------------------------------------------------------------------------
// --- Timer Hooks
// --------------------------------------------------------------------------

// Collection of { pending, timer, period, time, event } indexed by period
const clocks = {};

const CLOCKEVENT = (period) => 'dome.clock.' + period ;

const TIC_CLOCK = (clk) => () => {
  if (0 < clk.pending) {
    clk.time += clk.period ;
    emitter.emit(clk.event,clk.time);
  } else {
    clearInterval(clk.timer);
    delete clocks[clk.period];
  }
};

const INC_CLOCK = (period) => {
  let clk = clocks[period] ;
  if (!clk) {
    let event = CLOCKEVENT(period);
    let time = (new Date()).getTime();
    clk = { pending: 0, time, period, event };
    clocks[period] = clk ;
    let tic = TIC_CLOCK(clk);
    clk.timer = setInterval(tic,period);
  }
  clk.pending++;
};

const DEC_CLOCK = (period) => {
  let clk = clocks[period] ;
  if (clk) {
    clk.pending--;
  }
};

/**
   @summary Synchronized start & stop timer (Custom React Hook).
   @param {number} period - timer interval, in milliseconds (ms)
   @param {boolean} [initStart] - whether to initially start the timer (default is `false`)
   @return {timer} Timer object
   @description
   Create a local timer, synchronized on a global clock, that can be started
   and stopped on demand during the life cycle of the component.

   Each timer has its individual start & stop state. However,
   all timers with the same period _are_ synchronized with each others.

   The timer object has the following properties and methods:
   - `timer.start()` starts the timer,
   - `timer.stop()` starts the timer,
   - `timer.time` is the time stamp of the last clock (see below)

   It is safe to call `start()` and `stop()` whether the timer is running or not.
   When `timer.time` is `-1`, it means the timer is stopped.
   When `timer.time` is `0` it means the timer has just been started and no tic has
   been received yet. The time stamp is in milliseconds; it is shared among all
   timers synchronized on the same period and roughly equal to the `Date.getTime()`
   of the associated clock.

 */

export function useClock(period,initStart)
{
  const [time,setTime] = React.useState(initStart ? 0 : -1);
  const running = 0 <= time ;
  React.useEffect(() => {
    if (running) {
      INC_CLOCK(period);
      const event = CLOCKEVENT(period);
      emitter.on(event,setTime);
      return () => {
        DEC_CLOCK(period);
        emitter.off(event,setTime);
      };
    } else
      return undefined ;
  });
  return {
    time,
    start: () => { if (!running) setTime(0); },
    stop: () => { if (running) setTime(-1); }
  };
}

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

export class PP {
  constructor(moduleName) {
    this.moduleName = moduleName;
  }
  log(t) { console.log(`[${this.moduleName}] ${t}.`); }
  warning(t) { console.warn(`[${this.moduleName}] ${t}.`); }
  error(t) { console.error(`[${this.moduleName}] ${t}.`); }
}

// --------------------------------------------------------------------------
