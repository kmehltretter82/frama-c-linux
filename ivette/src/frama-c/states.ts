// --------------------------------------------------------------------------
// --- Frama-C States
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module frama-c/states
   @decsription
   Manage the current Frama-C project and projectified state values.
*/

import React from 'react';
import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import { Order } from 'dome/data/compare';
import * as GlobalStates from 'dome/data/states';
import { useModel } from 'dome/table/models';
import { CompactModel } from 'dome/table/arrays';
import * as Server from './server';

const PROJECT = 'frama-c.project';
const STATE_PREFIX = 'frama-c.state.';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const PP = new Dome.PP('States');

// --------------------------------------------------------------------------
// --- Synchronized Current Project
// --------------------------------------------------------------------------

let currentProject: string | undefined;

Server.onReady(async () => {
  try {
    const sr: Server.GetRequest<null, { id?: string }> = {
      kind: Server.RqKind.GET,
      name: 'kernel.project.getCurrent',
      input: Json.jNull,
      output: Json.jObject({ id: Json.jString }),
    };
    const current: { id?: string } = await Server.send(sr, null);
    currentProject = current.id;
    Dome.emit(PROJECT);
  } catch (error) {
    PP.error(`Fail to retrieve the current project. ${error.toString()}`);
  }
});

Server.onShutdown(() => {
  currentProject = '';
  Dome.emit(PROJECT);
});

// --------------------------------------------------------------------------
// --- Project API
// --------------------------------------------------------------------------

/**
   Current Project (Custom React Hook).
 */
export function useProject() {
  Dome.useUpdate(PROJECT);
  return currentProject;
}

/**
   Update Current Project.
   Make all states switching to their projectified value.
   Emits `PROJECT`.
   @param project - the project identifier
 */
export async function setProject(project: string) {
  if (Server.isRunning()) {
    try {
      const sr: Server.SetRequest<string, null> = {
        kind: Server.RqKind.SET,
        name: 'kernel.project.setCurrent',
        input: Json.jString,
        output: Json.jNull,
      };
      await Server.send(sr, project);
      currentProject = project;
      Dome.emit(PROJECT);
    } catch (error) {
      PP.error(`Fail to set the current project. ${error.toString()}`);
    }
  }
}

// --------------------------------------------------------------------------
// --- Cached GET Requests
// --------------------------------------------------------------------------

export interface UseRequestOptions<A> {
  offline?: A | null;
  pending?: A | null;
  onError?: A | null;
}

/**
   Cached GET request (Custom React Hook).

   Sends the specified GET request and returns its result.
   The request is send asynchronously and cached until any change.

   Null values in options mean that the last obtained value is kept.
 */
export function useRequest<In, Out>(
  rq: Server.GetRequest<In, Out>,
  params: In | undefined,
  options: UseRequestOptions<Out> = {},
): Out | undefined {
  const state = React.useRef<string>();
  const project = useProject();
  const [response, setResponse] =
    React.useState<Out | undefined>(options.offline ?? undefined);
  const footprint =
    project ? JSON.stringify([project, rq.name, params]) : undefined;

  const update = (opt: Out | undefined | null) => {
    if (opt !== null) setResponse(opt);
  };

  async function trigger() {
    if (project && rq && params !== undefined) {
      try {
        update(options.pending);
        const r = await Server.send(rq, params);
        update(r);
      } catch (error) {
        PP.error(`Fail in useRequest '${rq.name}'. ${error.toString()}`);
        update(options.onError);
      }
    } else {
      update(options.offline);
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

export type Tag = {
  name: string;
  label?: string;
  descr?: string;
};

const holdCurrent = { offline: null, pending: null, onError: null };

export type GetTags = Server.GetRequest<null, Tag[]>;

export function useTags(rq: GetTags): Map<string, Tag> {
  const tags = useRequest(rq, null, holdCurrent);
  return React.useMemo(() => {
    const m = new Map<string, Tag>();
    if (tags !== undefined)
      tags.forEach((tg) => m.set(tg.name, tg));
    return m;
  }, [tags]);
}

// --------------------------------------------------------------------------
// --- Synchronized States
// --------------------------------------------------------------------------

export interface Value<A> {
  name: string;
  signal: Server.Signal;
  getter: Server.GetRequest<null, A>;
}

export interface State<A> {
  name: string;
  signal: Server.Signal;
  getter: Server.GetRequest<null, A>;
  setter: Server.SetRequest<A, null>;
}

export interface Fetches<K, A> {
  reload: boolean;
  pending: number;
  updated: A[];
  removed: K[];
}

export interface Array<K, A> {
  name: string;
  order: Order<A>;
  getkey: (row: A) => K;
  signal: Server.Signal;
  reload: Server.GetRequest<null, null>;
  fetch: Server.GetRequest<number, Fetches<K, A>>;
}

// --------------------------------------------------------------------------
// --- Handler for Synchronized St byates
// --------------------------------------------------------------------------

interface Handler<A> {
  name: string;
  signal: Server.Signal;
  getter: Server.GetRequest<null, A>;
  setter?: Server.SetRequest<A, null>;
}

// shared for all projects
class SyncState<A> {
  UPDATE: string;
  handler: Handler<A>;
  upToDate: boolean;
  value?: A;

  constructor(h: Handler<A>) {
    this.handler = h;
    this.UPDATE = STATE_PREFIX + h.name;
    this.upToDate = false;
    this.value = undefined;
    this.update = this.update.bind(this);
    this.getValue = this.getValue.bind(this);
    this.setValue = this.setValue.bind(this);
    Dome.on(PROJECT, this.update);
  }

  getValue() {
    if (!this.upToDate && Server.isRunning()) {
      this.update();
    }
    return this.value;
  }

  async setValue(v: A) {
    try {
      this.upToDate = true;
      this.value = v;
      const setter = this.handler.getter;
      if (setter) await Server.send(setter, v);
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(
        `Fail to set value of syncState '${this.handler.name}'.`,
        `${error.toString()}`,
      );
    }
  }

  async update() {
    try {
      this.upToDate = true;
      const v = await Server.send(this.handler.getter, null);
      this.value = v;
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(
        `Fail to update syncState '${this.handler.name}'.`,
        `${error.toString()}`,
      );
    }
  }
}

// --------------------------------------------------------------------------
// --- Synchronized States Registry
// --------------------------------------------------------------------------

const syncStates = new Map<string, SyncState<any>>();

function getSyncState<A>(h: Handler<A>): SyncState<A> {
  const id = `${currentProject}@${h.name}`;
  let s = syncStates.get(id);
  if (!s) {
    s = new SyncState(h);
    syncStates.set(id, s);
  }
  return s;
}

Server.onShutdown(() => syncStates.clear());

// --------------------------------------------------------------------------
// --- Synchronized State Hooks
// --------------------------------------------------------------------------

/**
   Synchronization with a (projectified) server state.
 */
export function useSyncState<A>(
  st: State<A>,
): [A | undefined, (value: A) => void] {
  const s = getSyncState(st);
  Dome.useUpdate(PROJECT, s.UPDATE);
  Server.useSignal(s.handler.signal, s.update);
  return [s.getValue(), s.setValue];
}

/**
   Synchronization with a (projectified) server value.
 */
export function useSyncValue<A>(va: Value<A>): A | undefined {
  const s = getSyncState(va);
  Dome.useUpdate(s.update);
  Server.useSignal(s.handler.signal, s.update);
  return s.getValue();
}

// --------------------------------------------------------------------------
// --- Synchronized Arrays
// --------------------------------------------------------------------------

// one per project
class SyncArray<K, A> {
  handler: Array<K, A>;
  upToDate: boolean;
  fetching: boolean;
  model: CompactModel<K, A>;

  constructor(h: Array<K, A>) {
    this.handler = h;
    this.fetching = false;
    this.upToDate = false;
    this.model = new CompactModel(h.getkey);
    this.model.setNaturalOrder(h.order);
    this.fetch = this.fetch.bind(this);
    this.reload = this.reload.bind(this);
    this.update = this.update.bind(this);
  }

  update() {
    if (!this.upToDate && Server.isRunning()) this.fetch();
  }

  async fetch() {
    if (this.fetching || !Server.isRunning()) return;
    try {
      this.fetching = true;
      let pending;
      /* eslint-disable no-await-in-loop */
      do {
        const data = await Server.send(this.handler.fetch, 50);
        const { reload = false, removed = [], updated = [] } = data;
        const { model } = this;
        if (reload) model.removeAllData();
        model.updateData(updated);
        model.removeData(removed);
        if (reload || updated.length > 0 || removed.length > 0)
          model.reload();
        pending = data.pending ?? 0;
      } while (pending > 0);
      /* eslint-enable no-await-in-loop */
    } catch (error) {
      PP.error(
        `Fail to retrieve the value of syncArray '${this.handler.name}.`,
        `${error.toString()}`,
      );
    } finally {
      this.fetching = false;
      this.upToDate = true;
    }
  }

  async reload() {
    try {
      this.model.clear();
      this.upToDate = false;
      if (Server.isRunning()) {
        await Server.send(this.handler.reload, null);
        this.fetch();
      }
    } catch (error) {
      PP.error(
        `Fail to set reload of syncArray '${this.handler.name}'.`,
        `${error.toString()}`,
      );
    }
  }

}

// --------------------------------------------------------------------------
// --- Synchronized Arrays Registry
// --------------------------------------------------------------------------

const syncArrays = new Map<string, SyncArray<any, any>>();

function getSyncArray<K, A>(
  array: Array<K, A>,
): SyncArray<K, A> {
  const id = `${currentProject}@${array.name}`;
  let st = syncArrays.get(id);
  if (!st) {
    st = new SyncArray(array);
    syncArrays.set(id, st);
  }
  return st;
}

Server.onShutdown(() => syncArrays.clear());

// --------------------------------------------------------------------------
// --- Synchronized Array Hooks
// --------------------------------------------------------------------------

/**
   Force a Synchronized Array to Reload.
*/
export function reloadArray<K, A>(arr: Array<K, A>) {
  getSyncArray(arr).reload();
}

/**
   Use Synchronized Array (Custom React Hook).
   This React Hook is _not_ responsive to model updates, it only
   returns the array model.
   To listen to array updates, use `Models.useModel(model)` or `useSyncArray()`.
   Array views automatically listen to model updates.
 */
export function useSyncModel<K, A>(
  arr: Array<K, A>,
): CompactModel<K, A> {
  Dome.useUpdate(PROJECT);
  const st = getSyncArray(arr);
  React.useEffect(st.update);
  Server.useSignal(arr.signal, st.fetch);
  return st.model;
}

/**
   Use Synchronized Array (Custom React Hook).
   This React Hook is _not_ responsive to model updates, it only
   returns the array model.
   To listen to array updates, use `Models.useModel(model)` or `useSyncArray()`.
   Array views automatically listen to model updates.
 */
export function useSyncArray<K, A>(
  arr: Array<K, A>,
): A[] {
  Dome.useUpdate(PROJECT);
  const st = getSyncArray(arr);
  React.useEffect(st.update);
  Server.useSignal(arr.signal, st.fetch);
  useModel(st.model);
  return st.model.getArray();
}

// --------------------------------------------------------------------------
// --- Selection
// --------------------------------------------------------------------------

type AtLeastOne<T, U = { [K in keyof T]: Pick<T, K> }> =
  Partial<T> & U[keyof U];

export interface FullLocation {
  /** Function name. */
  readonly function: string;
  /** Marker identifier. */
  readonly marker: string;
}

/** An AST location.
 *
 *  Properties [[function]] and [[marker]] are optional,
 *  but at least one of the two must be set.
 */
export type Location = AtLeastOne<FullLocation>;

export interface HistorySelection {
  /** Previous locations with respect to the [[current]] one. */
  prevSelections: Location[];
  /** Next locations with respect to the [[current]] one. */
  nextSelections: Location[];
}

/** Actions on history selections:
 * - `HISTORY_PREV` jumps to previous history location
 *   (first in [[prevSelections]]).
 * - `HISTORY_NEXT` jumps to next history location
 *   (first in [[nextSelections]]).
 */
type HistorySelectActions = 'HISTORY_PREV' | 'HISTORY_NEXT';

/** A selection of multiple locations. */
export interface MultipleSelection {
  /** The index of the current selected location in [[possibleSelections]]. */
  index: number;
  /** All locations forming a multiple selection. */
  allSelections: Location[];
}

/** A select action on multiple locations. */
export interface MultipleSelect {
  readonly locations: Location[];
}

/** Select the [[index]]-nth location of the current multiple selection. */
export interface NthSelect {
  readonly index: number;
}

/** Actions on multiple selections:
 * - [[MultipleSelect]].
 * - [[NthSelect]].
 * - `MULTIPLE_PREV` jumps to previous location of the multiple selections.
 * - `MULTIPLE_NEXT` jumps to next location of the multiple selections.
 */
type MultipleSelectActions =
  MultipleSelect | NthSelect
  | 'MULTIPLE_PREV' | 'MULTIPLE_NEXT' | 'MULTIPLE_CLEAR';

export interface Selection {
  /** Current selection. May be one in [[history]] or [[multiple]]. */
  current?: Location;
  /** History of selections. */
  history: HistorySelection;
  /** Multiple selections at once. */
  multiple: MultipleSelection;
}

/** A select action on a location. */
export interface SingleSelect {
  readonly location: Location;
}

/** Actions on selection:
 * - [[SingleSelect]].
 * - [[HistorySelectActions]].
 * - [[MultipleSelectActions]].
 */
export type SelectionActions =
  SingleSelect | HistorySelectActions | MultipleSelectActions;

function isSingleSelect(a: SelectionActions): a is SingleSelect {
  return (a as SingleSelect).location !== undefined;
}

function isMultipleSelect(a: SelectionActions): a is MultipleSelect {
  return (a as MultipleSelect).locations !== undefined;
}

function isNthSelect(a: SelectionActions): a is NthSelect {
  return (a as NthSelect).index !== undefined;
}

/** Update selection to the given location. */
function selectLocation(s: Selection, location: Location): Selection {
  const [prevSelections, nextSelections] =
    s.current && s.current.function !== location.function ?
      [[s.current, ...s.history.prevSelections], []] :
      [s.history.prevSelections, s.history.nextSelections];
  return {
    ...s,
    current: location,
    history: { prevSelections, nextSelections },
  };
}

/** Compute the next selection picking from the current history, depending on
 *  action.
 */
function fromHistory(s: Selection, action: HistorySelectActions): Selection {
  switch (action) {
    case 'HISTORY_PREV': {
      const [pS, ...prevS] = s.history.prevSelections;
      return {
        ...s,
        current: pS,
        history: {
          prevSelections: prevS,
          nextSelections:
            [(s.current as Location), ...s.history.nextSelections],
        },
      };
    }
    case 'HISTORY_NEXT': {
      const [nS, ...nextS] = s.history.nextSelections;
      return {
        ...s,
        current: nS,
        history: {
          prevSelections:
            [(s.current as Location), ...s.history.prevSelections],
          nextSelections: nextS,
        },
      };
    }
    default:
      return s;
  }
}

/** Compute the next selection picking from the current multiple, depending on
 *  action.
 */
function fromMultipleSelections(
  s: Selection,
  action: 'MULTIPLE_PREV' | 'MULTIPLE_NEXT' | 'MULTIPLE_CLEAR',
): Selection {
  switch (action) {
    case 'MULTIPLE_PREV':
    case 'MULTIPLE_NEXT': {
      const index =
        action === 'MULTIPLE_NEXT' ?
          s.multiple.index + 1 :
          s.multiple.index - 1;
      if (0 <= index && index < s.multiple.allSelections.length) {
        const multiple = { ...s.multiple, index };
        return selectLocation(
          { ...s, multiple },
          s.multiple.allSelections[index],
        );
      }
      return s;
    }
    case 'MULTIPLE_CLEAR':
      return {
        ...s,
        multiple: {
          index: 0,
          allSelections: [],
        },
      };
    default:
      return s;
  }
}

/** Compute the next selection based on the current one and the given action. */
function reducer(s: Selection, action: SelectionActions): Selection {
  if (isSingleSelect(action)) {
    return selectLocation(s, action.location);
  }
  if (isMultipleSelect(action)) {
    if (action.locations.length === 0)
      return s;
    const selection = selectLocation(s, action.locations[0]);
    if (action.locations.length === 1)
      return selection;
    return {
      ...selection,
      multiple: {
        allSelections: action.locations,
        index: 0,
      },
    };
  }
  if (isNthSelect(action)) {
    const { index } = action;
    if (0 <= index && index < s.multiple.allSelections.length) {
      const location = s?.multiple.allSelections[index];
      const selection = selectLocation(s, location);
      const multiple = { ...selection.multiple, index };
      return { ...selection, multiple };
    }
    return s;
  }
  switch (action) {
    case 'HISTORY_PREV':
    case 'HISTORY_NEXT':
      return fromHistory(s, action);
    case 'MULTIPLE_PREV':
    case 'MULTIPLE_NEXT':
    case 'MULTIPLE_CLEAR':
      return fromMultipleSelections(s, action);
    default:
      return s;
  }
}

const GlobalSelection = new GlobalStates.State<Selection>({
  current: undefined,
  history: {
    prevSelections: [],
    nextSelections: [],
  },
  multiple: {
    index: 0,
    allSelections: [],
  },
});

/**
   Current selection.
 */
export function useSelection(): [Selection, (a: SelectionActions) => void] {
  const [selection, setSelection] = GlobalStates.useState(GlobalSelection);

  function update(action: SelectionActions) {
    const nextSelection = reducer(selection, action);
    setSelection(nextSelection);
  }

  return [selection, update];
}

// --------------------------------------------------------------------------
