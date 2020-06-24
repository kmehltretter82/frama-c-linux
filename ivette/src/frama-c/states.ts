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
import { ArrayModel } from 'dome/table/arrays';
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
  const footprint = project ? JSON.stringify([project, rq.name, params]) : undefined;

  const update = (opt: Out | undefined | null) => {
    if (opt !== null) setResponse(opt);
  }

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
}

const holdCurrent = { offline: null, pending: null, onError: null };

export type GetTags = Server.GetRequest<null, Tag[]>;

export function useTags(rq: GetTags): Map<string, Tag> {
  const tags = useRequest(rq, null, holdCurrent);
  return React.useMemo(() => {
    const m = new Map<string, Tag>();
    tags && tags.forEach((tg) => m.set(tg.name, tg));
    return m;
  }, tags);
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
  removed: Json.key<K>[]
}

export interface Array<K, A> {
  name: string;
  key: keyof A;
  signal: Server.Signal;
  fetch: Server.GetRequest<number, Fetches<K, A>>;
  reload: Server.GetRequest<null, null>;
}

type id = { project: string, state: string };

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
  insync: boolean;
  value?: A;

  constructor(h: Handler<A>) {
    this.handler = h;
    this.UPDATE = STATE + h.name;
    this.insync = false;
    this.value = undefined;
    this.update = this.update.bind(this);
    this.getValue = this.getValue.bind(this);
    this.setValue = this.setValue.bind(this);
    Dome.on(PROJECT, this.update);
  }

  getValue() {
    if (!this.insync && Server.isRunning()) {
      this.update();
    }
    return this.value;
  }

  async setValue(v: A) {
    try {
      this.insync = true;
      this.value = v;
      const setter = this.handler.getter;
      if (setter) {
        await Server.send(setter, v);
      }
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(
        `Fail to set value of syncState '${this.handler.name}'. ${error.toString()}`,
      );
    }
  }

  async update() {
    try {
      this.insync = true;
      const v = await Server.send(this.handler.getter, null);
      this.value = v;
      Dome.emit(this.UPDATE);
    } catch (error) {
      PP.error(`Fail to update syncState '${this.handler.name}'. ${error.toString()}`);
    }
  }
}

// --------------------------------------------------------------------------
// --- Synchronized States Registry
// --------------------------------------------------------------------------

const syncStates = new Map<id, SyncState<any>>();

function getSyncState<A>(h: Handler<A>): SyncState<A> {
  const id = { project: currentProject ?? '', state: h.name };
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
export function useSyncState<A>(st: State<A>): [A | undefined, (value: A) => void] {
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

export interface Model<A> {
  clear(): void;
  remove(key: string): void;
  add(entry: A): void;
  clear(): void;
}

// one per project
class SyncArray<K, A> {
  handler: Array<K, A>;
  model: Model<A>;
  insync: boolean;

  constructor(h: Array<K, A>, m?: Model<A>) {
    this.handler = h;
    this.insync = false;
    this.model = m ?? new ArrayModel<A>(h.key);
    this.fetch = this.fetch.bind(this);
    this.reload = this.reload.bind(this);
  }

  async fetch() {
    try {
      this.insync = true;
      const data = await Server.send(this.handler.fetch, 50);
      const { reload = false, removed = [], updated = [], pending = 0 } = data;
      const model = this.model;
      if (reload) model.clear();
      removed.forEach((k) => model.remove(k));
      updated.forEach((d) => model.add(d));
      if (pending > 0) setImmediate(this.fetch);
    } catch (error) {
      PP.error(
        `Fail to retrieve the value of syncArray '${this.handler.name}.`,
        `${error.toString()}`,
      );
    }
  }

  async reload() {
    try {
      await Server.send(this.handler.reload, null);
      this.model.clear();
      this.insync = false;
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

const syncArrays = new Map<id, SyncArray<any, any>>();

function getSyncArray<K, A>(arr: Array<K, A>, model?: Model<A>): SyncArray<K, A> {
  const id = { project: currentProject ?? '', state: arr.name };
  let a = syncArrays.get(id);
  if (!a) {
    a = new SyncArray(arr, model);
    syncArrays.set(id, a);
  } else {
    if (model && a.model !== model) {
      model.clear();
      a.reload();
      a.model = model;
    }
  }
  return a;
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
 */
export function useSyncArray<K, A>(arr: Array<K, A>, model?: Model<A>): Model<A> {
  const a = getSyncArray(arr, model);
  Dome.useUpdate(PROJECT);
  Server.useSignal(arr.signal, a.fetch);
  return a.model;
}

// --------------------------------------------------------------------------
// --- Selection
// --------------------------------------------------------------------------

type AtLeastOne<T, U = { [K in keyof T]: Pick<T, K> }> = Partial<T> & U[keyof U];

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
export interface Selection {

  /** Current selection. */
  current?: Location;
  /** Previous locations with respect to the [[current]] one. */
  prevSelections: Location[];
  /** Next locations with respect to the [[current]] one. */
  nextSelections: Location[];
}

/** A select action on a location. */
export interface SelectAction {
  readonly location: Location;
}

/** Actions on selection:
 * - [[SelectAction]].
 * - `GO_BACK` jumps to previous location (first in [[prevSelections]]).
 * - `GO_FORWARD` jumps to next location (first in [[nextSelections]]).
 */
export type SelectionActions = SelectAction | 'GO_BACK' | 'GO_FORWARD';

function isSelect(a: SelectionActions): a is SelectAction {
  return (a as SelectAction).location !== undefined;
}

/** Compute the next selection based on the current one and the given action. */
function reducer(s: Selection, action: SelectionActions): Selection {
  if (isSelect(action)) {
    const [prevSelections, nextSelections] =
      s.current && s.current.function !== action.location.function ?
        [[s.current, ...s.prevSelections], []] :
        [s.prevSelections, s.nextSelections];
    return {
      current: action.location,
      prevSelections,
      nextSelections,
    };
  }
  const [pS, ...prevS] = s.prevSelections;
  const [nS, ...nextS] = s.nextSelections;
  switch (action) {
    case 'GO_BACK':
      return {
        current: pS,
        prevSelections: prevS,
        nextSelections: [(s.current as Location), ...s.nextSelections],
      };
    case 'GO_FORWARD':
      return {
        current: nS,
        prevSelections: [(s.current as Location), ...s.prevSelections],
        nextSelections: nextS,
      };
    default:
      return s;
  }
}

const initialSelection: Selection = {
  current: undefined,
  prevSelections: [],
  nextSelections: [],
};

/**
   Current selection.
 */
export function useSelection(): [Selection, (a: SelectionActions) => void] {
  const [selection, setSelection] = React.useState(initialSelection);

  function update(action: SelectionActions) {
    const nextSelection = reducer(selection, action);
    setSelection(nextSelection);
  }

  return [selection, update];
}

// --------------------------------------------------------------------------
