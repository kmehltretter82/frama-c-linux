// --------------------------------------------------------------------------
// --- Frama-C States
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module frama-c/states
   @decsription
   Manage the current Frama-C project and projectified state values.
*/

import _ from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as Server from './server';

/**
 *  @event
 *  @name 'frama-c.project'
 *  @summary Current Project Updates
 *  @description
 *  Exported as `State.PROJECT` in public API.
 */
export const PROJECT = 'frama-c.project';

/**
 *  @event
 *  @name 'frama-c.state.*'
 *  @summary State Notification Events.
 *  @description
 *  Event `'frama-c.state.<id>'` for project `<id>`.
 *  The prefix `'frama-c.state.'` is exported as `States.STATE` in public API.
 */
export const STATE = 'frama-c.state.';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const PP = new Dome.PP('States');

// --------------------------------------------------------------------------
// --- Synchronized Current Project
// --------------------------------------------------------------------------

let currentProject: string | undefined;
let states: any = {};
const stateDefaults: any = {};

Server.onReady(async () => {
  try {
    const sr: Server.Request = {
      endpoint: 'kernel.project.getCurrent',
      params: {},
    };
    const current: { id: string } = await Server.GET(sr);
    currentProject = current.id;
    Dome.emit(PROJECT);
  } catch (error) {
    PP.error(`Fail to retrieve the current project. ${error.toString()}`);
  }
});

Server.onShutdown(() => {
  currentProject = '';
  states = {};
  Dome.emit(PROJECT);
});

// --------------------------------------------------------------------------
// --- Project API
// --------------------------------------------------------------------------

/**
 *  @summary Current Project (Custom React Hook).
 *  @return {string} the current project identifier, or `undefined`.
 */
export function useProject() {
  Dome.useUpdate(PROJECT);
  return currentProject;
}

/**
 *  @summary Update Current Project.
 *  @param {string} project - the project identifier
 *  @description
 *  Make all states switching to their projectified value.
 *  Emits `PROJECT`.
 */
export async function setProject(project: string) {
  if (Server.isRunning()) {
    try {
      const sr = { endpoint: 'kernel.project.setCurrent', params: project };
      await Server.SET(sr);
      currentProject = project;
      Dome.emit(PROJECT);
    } catch (error) {
      PP.error(`Fail to set the current project. ${error.toString()}`);
    }
  }
}

// --------------------------------------------------------------------------
// --- Projectified State
// --------------------------------------------------------------------------

function getValue(id: string, project?: string) {
  if (!project) return undefined;
  return _.get(states, [project, id], stateDefaults[id]);
}

function setValue(id: string, project: string | undefined, value: any) {
  if (!project) return;
  _.set(states, [project, id], value);
  Dome.emit(STATE + id, value);
}

/**
 *  @summary Define the default state value.
 *  @param {string} id - the state identifier (mandatory)
 *  @param {any} value - the new default state
 */
export function setStateDefault(id: string, value: any) {
  stateDefaults[id] = value;
}

/**
 *  @summary Projectified State (Custom React Hook).
 *  @param {string} id - the state identifier (mandatory)
 *  @return {array} `[state,setState]` for the specified project
 *  @description
 *  Returns a getter and a setter for the specified state
 *  in the specified or current project.
 *  The initial value of states is always `undefined`.
 *
 *  Each state is associated to a specific event `frama-c-state.<id>` which is
 *  is used to notify updates. The hook also updates on `PROJECT` notifications.
 */
export function useState(id: string) {
  Dome.useUpdate(PROJECT, STATE + id);
  const project = currentProject;
  const value = getValue(id, project);
  return [value, (v: any) => setValue(id, project, v)];
}

// --------------------------------------------------------------------------
// --- Cached GET Requests
// --------------------------------------------------------------------------

/**
 *  @summary Cached GET request (Custom React Hook).
 *  @param {string} rq - GET request name
 *  @param {any} [params] - GET request parameter
 *  @param {object} [options] - Special values
 *  @param {any} [options.offline] - Returned value when off-line
 *  @param {any} [options.pending] - Returned value when pending response
 *  @param {any} [options.error] - Returned value on request error
 *  @return {any} [result] GET request response (when available)
 *  @description
 *  Sends the specified GET request and returns its result.
 *  The request is send asynchronously and cached until any change in
 *  `rq`, `params`, current project or server activity.
 *
 *  The request is considered off-line as soon as either `rq` or `params` or
 *  current project takes a falsy value.
 *
 *  Default values for various situations can be defined in the options
 *  parameter, which is `undefined` unless specified, or `null` to keep the
 *  current value.
 *  For instance `{ pending: null }` will return `undefined` when off-line and
 *  in case of errors, but will keep the last received value until a new one is
 *  actually received.
 */
export function useRequest(rq: string, params: any, options: any = {}) {
  const state = React.useRef<string>();
  const project = useProject();
  const [response, setResponse] = React.useState(options.offline);
  const footprint = project ? JSON.stringify([project, rq, params]) : undefined;

  async function trigger() {
    if (project && rq && params !== undefined) {
      try {
        const r = await Server.GET({ endpoint: rq, params });
        setResponse(r);
      } catch (error) {
        PP.error(`Fail in useRequest '${rq}'. ${error.toString()}`);
        const err = options.error;
        setResponse(err);
      }
    } else {
      const off = options.offline;
      setResponse(off);
    }
  }

  React.useEffect(() => {
    if (state.current !== footprint) {
      state.current = footprint;
      trigger();
    }
  });

  return response;
}

// --------------------------------------------------------------------------
// --- Dictionaries
// --------------------------------------------------------------------------

/**
 *  @summary Cached GET request (Custom React Hook).
 *  @param {string} rq - GET request name
 *  @param {any} [params] - GET request parameter (default `'null'`)
 *  @param {object} [options] - Dictionary options
 *  @param {boolean} [options.key] - The property to index an item
 *         (default `'name'`)
 *  @param {boolean} [options.offline] - Keep the dictionary when offline
 *         (default `true`)
 *  @param {boolean} [options.pending] - Keep the dictionary when pending
 *         (default `true`)
 *  @param {boolean} [options.error] - Keep the dictionary on error
 *         (default `false`)
 *  @param {function} [options.filter] - Only index items satisfying the filter
 *         (default `undefined`)
 *  @return {object} [result] GET request response indexed by key
 *  @description
 *  Sends the specified GET request and returns its returned collection indexed
 *  by the provided key.
 *  Items in the collection that do have the key are not indexed.
 */
export function useDictionary(
  rq: string,
  params: any = null,
  options: any = {},
) {
  const {
    offline = true,
    pending = true,
    error = false,
    key = 'name',
    filter,
  } = options;
  const tags = useRequest(rq, params, {
    offline: offline ? null : undefined,
    pending: pending ? null : undefined,
    error: error ? null : undefined,
  });
  const dict = React.useMemo(() => {
    const d: any = {};
    _.forEach(tags, (tg) => {
      const k: any = tg[key];
      if (k && (!filter || filter(tg))) d[k] = tg;
    });
    return d;
  }, [key, tags, filter]);
  return dict;
}

// --------------------------------------------------------------------------
// --- Synchronized States
// --------------------------------------------------------------------------

// shared for all projects
class SyncState {
  id: any;
  UPDATE: string;
  signal: string;
  getRq: string;
  setRq: string;
  insync: boolean;
  effect: any;
  value: undefined;

  constructor(id: any) {
    this.id = id;
    this.UPDATE = STATE + id;
    this.signal = `${id}.sig`;
    this.getRq = `${id}.get`;
    this.setRq = `${id}.set`;
    this.insync = false;
    this.value = undefined;
    this.update = this.update.bind(this);
    this.effect = this.effect.bind(this);
    this.setValue = this.setValue.bind(this);
    Dome.on(PROJECT, this.update);
  }

  getValue() {
    if (!this.insync && Server.isRunning()) {
      this.update();
    }
    return this.value;
  }

  async setValue(v: any) {
    try {
      this.insync = true;
      this.value = v;
      const sr: Server.Request = { endpoint: this.setRq, params: v };
      await Server.SET(sr);
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(
        `Fail to set value of syncState '${this.id}'. ${error.toString()}`,
      );
    }
  }

  async update() {
    try {
      this.insync = true;
      const sr: Server.Request = { endpoint: this.getRq, params: {} };
      const v = await Server.GET(sr);
      this.value = v;
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(`Fail to update syncState '${this.id}'. ${error.toString()}`);
    }
  }
}

// --------------------------------------------------------------------------
// --- Synchronized States Registry
// --------------------------------------------------------------------------

let syncStates: any = {};

function getSyncState(id: any) {
  let s: any = syncStates[id];
  if (!s) {
    syncStates[id] = new SyncState(id);
    s = syncStates[id];
  }
  return s;
}

Server.onShutdown(() => (syncStates = {}));

// --------------------------------------------------------------------------
// --- Synchronized State Hooks
// --------------------------------------------------------------------------

/**
 *  @summary Use Synchronized State (Custom React Hook).
 *  @parameter {string} id - name of the server state
 *  @return {Array} `[ value , setValue ]` of the synchronized state
 *  @description
 *  Synchronization with some (projectified) server state:
 *  - sends a `<id>.get` request to obtain the current value of the state;
 *  - sends a `<id>.set` request to update the value of the state;
 *  - listens to `<id>.sig` signal to stay in sync with server updates.
 */
export function useSyncState(id: string) {
  const s = getSyncState(id);
  Dome.useUpdate(PROJECT, s.UPDATE);
  Server.useSignal(s.signal, s.update);
  return [s.value(), s.setValue];
}

/**
 *  @summary Use Synchronized Value (Custom React Hook).
 *  @parameter {string} id - name of the server state
 *  @return {any} current `value` of the state
 *  @description
 *  Synchronization with some (projectified) server value:
 *  - sends a `<id>.get` request to obtain the current value of the state;
 *  - listens to `<id>.sig` signal to stay in sync with server updates.
 */
export function useSyncValue(id: string) {
  const s = getSyncState(id);
  Dome.useUpdate(s.update);
  Server.useSignal(s.signal, s.update);
  return s.value();
}

// --------------------------------------------------------------------------
// --- Synchronized Arrays
// --------------------------------------------------------------------------

// one per project
class SyncArray {
  id: string;
  UPDATE: string;
  signal: string;
  fetchRq: string;
  reloadRq: string;
  index: any;
  insync: boolean;

  constructor(id: string) {
    this.id = id;
    this.UPDATE = STATE + id;
    this.signal = `${id}.sig`;
    this.fetchRq = `${id}.fetch`;
    this.reloadRq = `${id}.reload`;
    this.index = {};
    this.insync = false;
    this.fetch = this.fetch.bind(this);
    this.reload = this.reload.bind(this);
  }

  getItems() {
    if (!this.insync && Server.isRunning()) this.fetch();
    return this.index;
  }

  isEmpty() {
    return _.find(this.index, () => true) !== undefined;
  }

  async fetch() {
    try {
      this.insync = true;
      const sr: Server.Request = { endpoint: this.fetchRq, params: 50 };
      const data = await Server.GET(sr);
      const { reload = false, removed = [], updated = [], pending = 0 } = data;
      let reloaded = false;
      if (reload) {
        reloaded = this.isEmpty();
        this.index = {};
      }
      removed.forEach((key: any) => {
        delete this.index[key];
      });
      updated.forEach((item: any) => {
        this.index[item.key] = item;
      });
      if (reloaded || removed.length || updated.length) {
        this.index = { ...this.index };
        Dome.emit(this.UPDATE);
      }
      if (pending > 0) {
        this.fetch();
      }
    } catch (error) {
      PP.error(
        `Fail to retrieve the value of syncArray '${this.id}. ` +
        `${error.toString()}`,
      );
    }
  }

  async reload() {
    try {
      const sr: Server.Request = { endpoint: this.reloadRq, params: {} };
      await Server.SET(sr);
      this.index = {};
      this.insync = false;
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(
        `Fail to set reload of syncArray '${this.id}'. ${error.toString()}`,
      );
    }
  }
}

// --------------------------------------------------------------------------
// --- Synchronized Arrays Registry
// --------------------------------------------------------------------------

let syncArrays = {}; // Model by project & id

function getSyncArray(id: string) {
  const path = [currentProject || '', id];
  let a = _.get(syncArrays, path);
  if (!a) {
    a = new SyncArray(id);
    _.set(syncArrays, path, a);
  }
  return a;
}

Server.onShutdown(() => (syncArrays = {}));

// --------------------------------------------------------------------------
// --- Synchronized Array Hooks
// --------------------------------------------------------------------------

/**
 *  @summary Force a Synchronized Array to Reload.
 *  @description
 *  Sends the `<id>.reload` request to the server for
 *  triggering a complete array reload.
 */
export function reloadArray(id: string) {
  getSyncArray(id).reload();
}

/**
 *  @summary Use Synchronized Array (Custom React Hook).
 *  @parameter {string} id - name of the server array
 *  @return {object} items indexed by their identifiers
 *  @description
 *  Synchronization with some (projectified) server array:
 *  - sends `<id>.fetch` requests to obtain the updated entries;
 *  - listens to `<id>.sig` signal to stay in sync with server updates.
 */
export function useSyncArray(id: string) {
  const a = getSyncArray(id);
  Dome.useUpdate(PROJECT, a.UPDATE);
  Server.useSignal(a.signal, a.fetch);
  return a.getItems();
}

// --------------------------------------------------------------------------
// --- Selection
// --------------------------------------------------------------------------

/** An AST location. */
export interface Location {
  /** Function name. */
  readonly function: string;
  /** Marker identifier. */
  readonly marker?: string;
}

export interface Selection {
  /** Current selection. */
  current?: Location;
  /** Previous locations with respect to the [[current]] one. */
  prevSelections: Location[];
  /** Next locations with respect to the [[current]] one. */
  nextSelections: Location[];
}

/** An action on a location. */
export interface LocationAction {
  /** Type of action:
   * - `SELECT` selects a given [[location]].
   * - `GOTO` jumps to a given [[location]], and empties [[nextSelections]].
   */
  readonly type: 'SELECT' | 'GOTO';
  readonly location: Location;
}

/** Actions on selection:
 * - [[LocationAction]].
 * - `GO_BACK` jumps to previous location (first in [[prevSelections]]).
 * - `GO_FORWARD` jumps to next location (first in [[nextSelections]]).
 */
export type SelectionActions = LocationAction | 'GO_BACK' | 'GO_FORWARD';

function isOnLocation(a: SelectionActions): a is LocationAction {
  return (a as LocationAction).type !== undefined;
}

/** Compute the next selection based on the current one and the given action. */
function reducer(s: Selection, action: SelectionActions) {
  if (isOnLocation(action)) {
    switch (action.type) {
      case 'SELECT':
        // Save current location if the selected one is in a different function.
        if (s.current?.function !== action.location.function &&
          (s.prevSelections.length !== 0 || s.nextSelections.length !== 0)) {
          return {
            current: action.location,
            prevSelections: [s.current, ...s.prevSelections],
            nextSelections: s.nextSelections,
          };
        }
        return { ...s, current: action.location };
      case 'GOTO':
        return {
          current: action.location,
          prevSelections: [s.current, ...s.prevSelections],
          nextSelections: [],
        };
      default:
        return s;
    }
  } else {
    const [pS, ...prevS] = s.prevSelections;
    const [nS, ...nextS] = s.nextSelections;
    switch (action) {
      case 'GO_BACK':
        return {
          current: pS,
          prevSelections: prevS,
          nextSelections: [s.current, ...s.nextSelections],
        };
      case 'GO_FORWARD':
        return {
          current: nS,
          prevSelections: [s.current, ...s.prevSelections],
          nextSelections: nextS,
        };
      default:
        return s;
    }
  }
}

const SELECTION = 'kernel.selection';

const initialSelection = {
  current: undefined,
  prevSelections: [],
  nextSelections: [],
};
setStateDefault(SELECTION, initialSelection);

/**
 *  Current selection.
 *  @return {array} The current selection and the function to update it.
 */
export function useSelection(): [Selection, (a: SelectionActions) => void] {
  const [selection, setSelection] = useState(SELECTION);

  function update(action: SelectionActions) {
    const nextSelection = reducer(selection, action);
    setSelection(nextSelection);
  }

  return [selection, update];
}

// --------------------------------------------------------------------------
