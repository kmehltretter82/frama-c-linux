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

import _ from 'lodash';
import React from 'react';
import ReactDOM from 'react-dom';
import type Emitter from 'events';
import { AppContainer } from 'react-hot-loader';
import { remote, ipcRenderer } from 'electron';
import SYS, * as System from 'dome/system';
import * as Json from 'dome/data/json';
import * as Settings from 'dome/data/settings';
import './style.css';

// --------------------------------------------------------------------------
// --- Context
// --------------------------------------------------------------------------

// main window focus
var focus = true;

function setContextAppNode() {
  const node = document.getElementById('app');
  if (node) {
    node.className =
      'dome-container dome-platform-' + System.platform +
      (focus ? ' dome-window-active' : ' dome-window-inactive');
  }
  return node;
}

// --------------------------------------------------------------------------
// --- Helpers
// --------------------------------------------------------------------------

/** Configured to be `'true'` when in development mode. */
export const DEVEL = System.DEVEL;

export type PlatformKind = 'linux' | 'macos' | 'windows';

/** System platform. */
export const platform: PlatformKind = (System.platform as PlatformKind);

// --------------------------------------------------------------------------
// --- Application Emitter
// --------------------------------------------------------------------------

/** Register a callback on Dome event. */
export function on(
  evt: string,
  job: (...args: any[]) => void,
) { System.emitter.on(evt, job); }

/** Register a callback on Dome event. */
export function off(
  evt: string,
  job: (...args: any[]) => void,
) { System.emitter.off(evt, job); }

/** Emit a Dome event (Same as [[dome/misc/system.event]]). */
export function emit(
  evt: string,
  ...args: any[]
) { System.emitter.emit(evt, ...args); }

// --------------------------------------------------------------------------
// --- Application Events
// --------------------------------------------------------------------------

/** Emits the `dome.update` event. */
export function update() { emit('dome.update'); }

/** Update event handler. */
export function onUpdate(job: () => void) { on('dome.update', job); }

/** Unregister an update event handler. */
export function offUpdate(job: () => void) { off('dome.update', job); }

/** Reload event handler. */
export function onReload(job: () => void) { on('dome.reload', job); }
ipcRenderer.on('dome.ipc.reload', () => emit('dome.reload'));

/** Command-line arguments event handler. */
export function onCommand(
  job: (argv: string[], workingDir: string) => void
) { on('dome.command', job); }
ipcRenderer.on('dome.ipc.command', (_event, argv, wdir) => {
  SYS.SET_COMMAND(argv, wdir);
  emit('dome.command', argv, wdir);
});

// --------------------------------------------------------------------------
// --- Window Management
// --------------------------------------------------------------------------

export function isApplicationWindow() {
  return process.argv.includes(SYS.WINDOW_APPLICATION_ARGV);
}

export function isPreferencesWindow() {
  return process.argv.includes(SYS.WINDOW_PREFERENCES_ARGV);
}

// --------------------------------------------------------------------------
// --- Window Title
// --------------------------------------------------------------------------

/** Sets the modified status of the window-frame flag.
    User feedback is platform dependent. */
export function setModified(modified = false) {
  ipcRenderer.send('dome.ipc.window.modified', modified);
}

/** Sets the window-frame title. */
export function setTitle(title: string) {
  ipcRenderer.send('dome.ipc.window.title', title);
}

// --------------------------------------------------------------------------
// --- Window Container
// --------------------------------------------------------------------------

function setContainer(
  Component: React.FunctionComponent | React.ComponentClass
) {
  Settings.synchronize();
  const appNode = setContextAppNode();
  const appContents = React.createElement(Component);
  const appContainer = React.createElement(AppContainer, {}, [appContents]);
  ReactDOM.render(appContainer, appNode);
}

// --------------------------------------------------------------------------
// --- Main Content
// --------------------------------------------------------------------------

/**
   Defines the user's main window content.

   Binds the component to the main window.
   <strong>Notes:</strong> a `<Component/>` instance is generated and rendered in the `#app`
   window element. Its class name is set to `dome-platform-<platform>` with
   the `<platform>` set to the `Dome.platform` value. This class name can be used
   as a CSS selector for platform-dependent styling.

   @param Component - to be rendered in the main window
*/
export function setApplicationWindow(
  Component: React.FunctionComponent | React.ComponentClass
) {
  if (isApplicationWindow()) setContainer(Component);
}

// --------------------------------------------------------------------------
// --- Settings Window
// --------------------------------------------------------------------------

/**
   Defines the user's preferences window content.

   <strong>Notes:</strong> a `<Component/>` instance is generated and rendered in the `#app`
   window element. Its class name is set to `dome-platform-<platform>` with
   the `<platform>` set to the `Dome.platform` value. This class name can be used
   as a CSS selector for platform-dependent styling.

   @param Component - to be rendered in the preferences window
*/
export function setPreferencesWindow(
  Component: React.FunctionComponent | React.ComponentClass
) {
  if (isPreferencesWindow()) setContainer(Component);
}

// --------------------------------------------------------------------------
// --- MenuBar Management
// --------------------------------------------------------------------------

const customItemCallbacks = new Map<string, (() => void)>();

/**
   Create a new custom menu in the menu bar.

   This function can be triggered at any time, and will eventually trigger
   an update of the whole application menubar.

   It is also possible to call this function from the main process.

   @param label - the menu title (shall be unique)
*/
export function addMenu(label: string) {
  ipcRenderer.send('dome.ipc.menu.addmenu', label);
}

export type MenuName = 'File' | 'Edit' | 'View' | string;
export type MenuItemType = 'normal' | 'separator' | 'checkbox' | 'radio';

export interface MenuItemProps {
  /** The label of the menu to insert the item in. */
  menu: MenuName;
  /** The menu item identifier. Shall be unique in the _entire_ menu bar. */
  id: string;
  /** Default is `'normal'`. */
  type: MenuItemType;
  /** Item label. Only optional for separators. */
  label?: string;
  /** Item is visible or not (default is `true`). */
  visible?: boolean;
  /** Enabled item (default is `true`). */
  enabled?: boolean;
  /** Item status for radio and checkbox. Default is `false`. */
  checked?: boolean;
  /** Keyboard shortcut. */
  key?: string;
  /** Callback. */
  onClick?: () => void;
}

/**
   Inserts a new custom item in a menu.

   The menu can be modified later with [[setMenuItem]].

   When clicked, the menu-item will also trigger a `'dome.menu.clicked'(id)`
   event on all application windows.  The item callback, if any, is invoked only
   in the process that specify it.

   Key short cuts shall be specified with the following codes:
   - `"Cmd+<Key>"` for command (MacOS) or control (Linux) key
   - `"Alt+<Key>"` for command+option (MacOS) or alt (Linux) key
   - `"Meta+<Key>"` for command+shift (MacOS) or control+alt (Linux) key

   This function can be triggered at any time, and will eventually trigger
   an update of the complete application menubar.
   It is also possible to call this function from the main process.
*/
export function addMenuItem(props: MenuItemProps) {
  if (!props.id && props.type !== 'separator') {
    console.error('[Dome] Missing menu-item identifier', props);
    return;
  }
  const { onClick, ...options } = props;
  if (onClick) customItemCallbacks.set(props.id, onClick);
  ipcRenderer.send('dome.ipc.menu.addmenuitem', options);
}

export interface MenuItemOptions {
  id: string;
  label?: string;
  visible?: boolean;
  enabled?: boolean;
  checked?: boolean;
  onClick?: null | (() => void);
}

/**
   Update properties of an existing menu-item.

   If an `onClick` callback is specified, it will _replace_ the previous one.
   You shall specify `null` to remove the previously registered callback
   (`undefined` callback is ignored).

   This function can be triggered at any time, and will possibly trigger
   an update of the application menubar if the properties
   can not be changed dynamically in Electron.

   It is also possible to call this function from the main process.
 */
export function setMenuItem(options: MenuItemOptions) {
  const { onClick, ...updates } = options;
  if (onClick === null) {
    customItemCallbacks.delete(options.id);
  } else if (onClick !== undefined) {
    customItemCallbacks.set(options.id, onClick);
  }
  ipcRenderer.send('dome.ipc.menu.setmenuitem', updates);
}

ipcRenderer.on('dome.ipc.menu.clicked', (_sender, id: string) => {
  const callback = customItemCallbacks.get(id);
  callback && callback();
});

// --------------------------------------------------------------------------
// --- Context Menus
// --------------------------------------------------------------------------

export interface PopupMenuItemProps {
  /** Item label. */
  label: string;
  /** Optional menu identifier. */
  id?: string;
  /** Displayed item, default is `true`. */
  display?: boolean;
  /** Enabled item, default is `true`. */
  enabled?: boolean;
  /** Checked item, default is `false`. */
  checked?: boolean;
  /** Item selection callback. */
  onClick?: (() => void);
}

export type PopupMenuItem = PopupMenuItemProps | 'separator';

/**
   Popup a contextual menu.

   Items can be separated by inserting a `'separator'` constant string in the
   array. Item identifier and label default to each others. Alternatively, an
   item can be specified by a single string that will be used for both its label
   and identifier. Undefined or null items are allowed (and skipped).

   The menu is displayed at the current mouse location.  The callback is called
   with the selected item identifier or label.  If the menu popup is canceled by
   the user, the callback is called with `undefined`.

   Example:

   * ```ts
   *    let myPopup = (_evt) => Dome.popupMenu([ …items… ],(id) => … );
   *    <div onRightClick={myPopup}>...</div>
   * ```

*/
export function popupMenu(
  items: PopupMenuItem[],
  callback?: (item: string | undefined) => void,
) {
  const { Menu, MenuItem } = remote;
  const menu = new Menu();
  var selected = '';
  var kid = 0;
  items.forEach((item) => {
    if (item === 'separator')
      menu.append(new MenuItem({ type: 'separator' }));
    else if (item) {
      const { display = true, enabled, checked } = item;
      if (display) {
        const label = item.label || '#' + (++kid);
        const id = item.id || label;
        const click = () => {
          selected = id;
          item.onClick && item.onClick();
        };
        const type = checked !== undefined ? 'checkbox' : 'normal';
        menu.append(new MenuItem({ label, enabled, type, checked, click }));
      }
    }
  });
  const job = callback ? () => callback(selected) : undefined;
  menu.popup({ window: remote.getCurrentWindow(), callback: job });
}

// --------------------------------------------------------------------------
// --- Closing
// --------------------------------------------------------------------------

ipcRenderer.on('dome.ipc.closing', System.doExit);

// --------------------------------------------------------------------------
// --- Focus Management
// --------------------------------------------------------------------------

/** Current focus state of the main window. See also [[useWindowFocus]]. */
export function isFocused() { return focus; }

ipcRenderer.on('dome.ipc.focus', (_sender, value) => {
  focus = value;
  setContextAppNode();
  System.emitter.emit('dome.focus', value);
});

/** Return the current window focus. See [[isfocused]]. */
export function useWindowFocus(): boolean {
  useUpdate('dome.focus');
  return focus;
}

// --------------------------------------------------------------------------
// --- Web Navigation
// --------------------------------------------------------------------------

ipcRenderer.on(
  'dome.ipc.href',
  (href) => System.emitter.emit('dome.href', href)
);

/**
   Register a callback to handle clicks on a local `<a href=...>`
   with non-http protocoles.

   URL with an `http://` protocole are opened externally
   by the user's default browser.

   Other URLs shall be treated by the application _via_ this callback.
*/
export function onDOMhref(callback: (href: string) => void) {
  System.emitter.on('dome.href', callback);
}

// --------------------------------------------------------------------------
// --- React Hooks
// --------------------------------------------------------------------------

/**
   Hook to re-render on demand (Custom React Hook).
   Returns a callback to trigger a render on demand.
*/
export function useForceUpdate() {
  const [tac, onTic] = React.useState(false);
  return () => onTic(!tac);
}

/**
   Hook to re-render on Dome events (Custom React Hook).
   @param events - event names, defaults to a single `'dome.update'`.
*/
export function useUpdate(...events: string[]) {
  const update = useForceUpdate();
  React.useEffect(() => {
    const trigger = () => setImmediate(update);
    if (events.length == 0) events.push('dome.update');
    events.forEach((evt) => System.emitter.on(evt, trigger));
    return () => events.forEach((evt) => System.emitter.off(evt, trigger));
  });
}

/**
   Hook to register callbacks to Dome events (Custom React Hook).

   Register the callback on event until the component is unmount.
   Do not force the component to re-render (unless the callback does).

   @param event - Event to register on
   @param callback - The callback to register
*/
export function useEvent(event: string, callback: () => void) {
  React.useEffect(() => {
    System.emitter.on(event, callback);
    return () => { System.emitter.off(event, callback); };
  });
}

/**
   Hook to register callbacks to events on an emitter (Custom React Hook).
   Similar to [[useEvent]].
*/
export function useEmitter(
  emitter: Emitter,
  evt: string,
  callback: () => void,
) {
  React.useEffect(() => {
    emitter.on(evt, callback);
    return () => { emitter.off(evt, callback); };
  });
}

// --------------------------------------------------------------------------
// --- Commands Hooks
// --------------------------------------------------------------------------

/**
   Hook for command-line interface (Custom React Hook).
   Returns the command-line arguments and working directory for the application
   instance running in the window. Automatically updated on `dome.command` events.

   @returns `[argv,wdir]` command-line arguments and working directory

   See also [[onCommand]] event handler.
*/
export function useCommand(): [string[], string] {
  useUpdate('dome.command');
  const wdir = System.getWorkingDir();
  const argv = System.getArguments();
  return [argv, wdir];
}

// --------------------------------------------------------------------------
// --- Timer Hooks
// --------------------------------------------------------------------------

interface Clock {
  timer?: NodeJS.Timeout;
  pending: number; // Number of listeners
  time: number; // Ellapsed time since firts pending
  event: string; // Tic events
  period: number; // Period
};

// Collection of clocks indexed by period
const CLOCKS = new Map<number, Clock>();

const CLOCKEVENT = (period: number) => 'dome.clock.' + period;

const TIC_CLOCK = (clk: Clock) => () => {
  if (0 < clk.pending) {
    clk.time += clk.period;
    System.emitter.emit(clk.event, clk.time);
  } else {
    if (clk.timer) clearInterval(clk.timer);
    CLOCKS.delete(clk.period);
  }
};

const INC_CLOCK = (period: number) => {
  let clk = CLOCKS.get(period);
  if (!clk) {
    let event = CLOCKEVENT(period);
    let time = (new Date()).getTime();
    clk = { pending: 0, time, period, event };
    clk.timer = setInterval(TIC_CLOCK(clk), period);
    CLOCKS.set(period, clk);
  }
  clk.pending++;
  return clk.event;
};

const DEC_CLOCK = (period: number) => {
  let clk = CLOCKS.get(period);
  if (clk) clk.pending--;
};

export interface Timer {
  /** Starts the timer, if not yet. */
  start(): void;
  /** Stops the timer. Can be restarted after. */
  stop(): void;
  /** Elapsed time (in milliseconds). */
  time: number;
  /** Running timer. */
  running: boolean;
}

/**
   Synchronized start & stop timer (Custom React Hook).

   Create a local timer, synchronized on a global clock, that can be started
   and stopped on demand during the life cycle of the component.

   Each timer has its individual start & stop state. However,
   all timers with the same period _are_ synchronized with each others.

   @param period - timer interval, in milliseconds (ms)
   @param initStart - whether to initially start the timer (default is `false`)

 */
export function useClock(period: number, initStart: boolean): Timer {
  const started = React.useRef(0);
  const [time, setTime] = React.useState(0);
  const [running, setRunning] = React.useState(initStart);
  const start = React.useCallback(() => setRunning(false), []);
  const stop = React.useCallback(() => {
    setRunning(false);
    setTime(0);
    started.current = 0;
  }, []);
  React.useEffect(() => {
    if (running) {
      const event = INC_CLOCK(period);
      const callback = (t: number) => {
        if (!started.current) started.current = t;
        else setTime(t - started.current);
      };
      System.emitter.on(event, callback);
      return () => {
        System.emitter.off(event, callback);
        DEC_CLOCK(period);
      };
    } else
      return undefined;
  }, [running]);
  return { time, running, start, stop };
}

// --------------------------------------------------------------------------
// --- Settings Hookds
// --------------------------------------------------------------------------

export type FlipState = [boolean, (newState?: boolean) => void];

/**
   Bool window settings helper. Default is `false` unless specified.
   See also [[dome/data/settings]].
   @returns `[state,flipState]` where flipState can be invoked with an
   optional argument. By default, `flipState()` invert the state and
    `flipState(s)` set the state to `s`.
*/
export function useBoolSettings(
  key: string | undefined,
  defaultValue = false,
): FlipState {
  const [state, setState] = Settings.useWindowSettings(
    key, Json.jBoolean, defaultValue
  );
  const flipState = React.useCallback(
    (v) => setState(v === undefined ? !state : v),
    [state, setState]
  );
  return [state, flipState];
}

/** Number window settings helper. Default is `0` unless specified. */
export function useNumberSettings(key: string | undefined, defaultValue = 0) {
  return Settings.useWindowSettings(
    key, Json.jNumber, defaultValue
  );
}

/** String window settings. Default is `''` unless specified). */
export function useStringSettings(key: string | undefined, defaultValue = '') {
  return Settings.useWindowSettings(
    key, Json.jString, defaultValue
  );
}

/** Optional string window settings. Default is `undefined`. */
export function useStringOptSettings(key: string | undefined) {
  return Settings.useWindowSettings(
    key, Json.jString, undefined
  );
}

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

export class Debug {
  moduleName: string;
  constructor(moduleName: string) {
    this.moduleName = moduleName;
  }
  log(...args: any) {
    if (DEVEL) console.log(`[${this.moduleName}]`, ...args);
  }
  warn(...args: any) {
    if (DEVEL) console.warn(`[${this.moduleName}]`, ...args);
  }
  error(...args: any) {
    if (DEVEL) console.error(`[${this.moduleName}]`, ...args);
  }
}

// --------------------------------------------------------------------------
