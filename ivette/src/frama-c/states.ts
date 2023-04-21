/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

// --------------------------------------------------------------------------
// --- Frama-C States
// --------------------------------------------------------------------------

/**
 * Manage the current Frama-C project and projectified state values.
 * @packageDocumentation
 * @module frama-c/states
*/

import React from 'react';
import * as Dome from 'dome';
import { Order } from 'dome/data/compare';
import { GlobalState, useGlobalState } from 'dome/data/states';
import { Client, useModel } from 'dome/table/models';
import { CompactModel } from 'dome/table/arrays';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Server from './server';
import * as Status from 'frama-c/kernel/Status';

// --------------------------------------------------------------------------
// --- Pretty Printing (Browser Console)
// --------------------------------------------------------------------------

const D = new Dome.Debug('States');

// --------------------------------------------------------------------------
// --- Cached GET Requests
// --------------------------------------------------------------------------

/** Options to tweak the behavior of `useRequest()`. Null values means
    keeping the last result. */
export interface UseRequestOptions<A> {
  /** Returned value in case where the server goes offline. */
  offline?: A | null;
  /** Temporary returned value when the request is pending. */
  pending?: A | null;
  /** Returned value when the request fails. */
  onError?: A | null;
  /** Re-send the request when any of the signals are sent. */
  onSignals?: Server.Signal[];
}

/**
  Cached GET request (Custom React Hook).

  Sends the specified GET request and returns its result. The request is send
  asynchronously and cached until any change in the request parameters or server
  state. The change in the server state are tracked by the signals specified
  when registering the request or by the one in options.onSignals if specified.

  Options can be used to tune more precisely the behavior of the hook.
 */
export function useRequest<In, Out>(
  rq: Server.GetRequest<In, Out>,
  params: In | undefined,
  options: UseRequestOptions<Out> = {},
): Out | undefined {
  const initial = options.offline ?? undefined;
  const [response, setResponse] = React.useState<Out | undefined>(initial);
  const updateResponse = (opt: Out | undefined | null): void => {
    if (opt !== null) setResponse(opt);
  };

  // Fetch Request
  async function trigger(): Promise<void> {
    if (Server.isRunning() && params !== undefined) {
      try {
        updateResponse(options.pending);
        const r = await Server.send(rq, params);
        updateResponse(r);
      } catch (error) {
        D.error(`Fail in useRequest '${rq.name}'. ${error}`);
        updateResponse(options.onError);
      }
    } else {
      updateResponse(options.offline);
    }
  }

  // Server & Cache Management
  Server.useStatus();
  const cached = React.useRef('');
  React.useEffect(() => {
    if (Server.isRunning()) {
      const footprint = JSON.stringify([rq.name, params]);
      if (cached.current !== footprint) {
        cached.current = footprint;
        trigger();
      }
    } else {
      if (cached.current !== '') {
        cached.current = '';
        updateResponse(options.offline);
      }
    }
  });

  // Signal Management
  const signals = rq.signals.concat(options.onSignals ?? []);
  React.useEffect(() => {
    signals.forEach((s) => Server.onSignal(s, trigger));
    return () => {
      signals.forEach((s) => Server.offSignal(s, trigger));
    };
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
// --- Synchronized States from API
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
// --- Handler for Synchronized States
// --------------------------------------------------------------------------

interface Handler<A> {
  name: string;
  signal: Server.Signal;
  getter: Server.GetRequest<null, A>;
  setter?: Server.SetRequest<A, null>;
}

enum SyncStatus { OffLine, Loading, Loaded }

class SyncState<A> extends GlobalState<A | undefined> {
  handler: Handler<A>;
  status = SyncStatus.OffLine;

  constructor(h: Handler<A>) {
    super(undefined);
    this.handler = h;
    this.fetch = this.fetch.bind(this);
  }

  signal(): Server.Signal { return this.handler.signal; }

  online(): void {
    if (Server.isRunning() && this.status === SyncStatus.OffLine)
      this.fetch();
  }

  offline(): void {
    this.status = SyncStatus.OffLine;
    this.setValue(undefined);
  }

  async fetch(): Promise<void> {
    try {
      if (Server.isRunning()) {
        this.status = SyncStatus.Loading;
        const v = await Server.send(this.handler.getter, null);
        this.status = SyncStatus.Loaded;
        this.setValue(v);
      }
    } catch (error) {
      D.error(
        `Fail to update SyncState '${this.handler.name}'.`,
        `${error}`,
      );
      this.setValue(undefined);
    }
  }

}

// --------------------------------------------------------------------------
// --- Synchronized States Registry
// --------------------------------------------------------------------------

const syncStates = new Map<string, SyncState<unknown>>();

function lookupSyncState<A>(h: Handler<A>): SyncState<A> {
  let s = syncStates.get(h.name) as SyncState<A> | undefined;
  if (!s) {
    s = new SyncState(h);
    syncStates.set(h.name, s);
  }
  return s;
}

Server.onShutdown(() => {
  syncStates.forEach((st) => st.offline());
  syncStates.clear();
});

// --------------------------------------------------------------------------
// --- Synchronized State Hooks
// --------------------------------------------------------------------------

/** Synchronization with a (projectified) server state. */
export function useSyncState<A>(
  state: State<A>,
): [A | undefined, (value: A) => void] {
  Server.useStatus();
  const st = lookupSyncState(state);
  Server.useSignal(st.signal(), st.fetch);
  st.online();
  return useGlobalState(st);
}

/** Synchronization with a (projectified) server value. */
export function useSyncValue<A>(value: Value<A>): A | undefined {
  Server.useStatus();
  const st = lookupSyncState(value);
  Server.useSignal(st.signal(), st.fetch);
  st.online();
  const [v] = useGlobalState(st);
  return v;
}

// --------------------------------------------------------------------------
// --- Synchronized Arrays
// --------------------------------------------------------------------------

class SyncArray<K, A> {
  handler: Array<K, A>;
  upToDate: boolean;
  fetching: boolean;
  signaled: boolean; // during fetching or offline
  model: CompactModel<K, A>;

  constructor(h: Array<K, A>) {
    this.handler = h;
    this.fetching = false;
    this.upToDate = false;
    this.signaled = false;
    this.model = new CompactModel(h.getkey);
    this.model.setNaturalOrder(h.order);
    this.fetch = this.fetch.bind(this);
    this.reload = this.reload.bind(this);
  }

  online(): void {
    if (!this.upToDate && Server.isRunning())
      this.fetch();
  }

  offline(): void {
    this.upToDate = false;
    this.model.clear();
  }

  async fetch(): Promise<void> {
    if (this.fetching || !Server.isRunning()) {
      this.signaled = true;
      return;
    }
    try {
      this.fetching = true;
      let pending;
      /* eslint-disable no-await-in-loop */
      do {
        this.signaled = false;
        const data = await Server.send(this.handler.fetch, 20000);
        const { reload = false, removed = [], updated = [] } = data;
        const { model } = this;
        if (reload) model.removeAllData();
        model.updateData(updated);
        model.removeData(removed);
        if (reload || updated.length > 0 || removed.length > 0)
          model.reload();
        pending = data.pending ?? 0;
      } while (this.signaled || pending > 0);
      /* eslint-enable no-await-in-loop */
    } catch (error) {
      D.error(
        `Fail to retrieve the value of syncArray '${this.handler.name}'.`,
        error,
      );
    } finally {
      this.signaled = false;
      this.fetching = false;
      this.upToDate = true;
    }
  }

  async reload(): Promise<void> {
    try {
      this.model.clear();
      this.upToDate = false;
      this.signaled = false;
      if (Server.isRunning()) {
        await Server.send(this.handler.reload, null);
        this.fetch();
      }
    } catch (error) {
      D.error(
        `Fail to set reload of syncArray '${this.handler.name}'.`,
        `${error}`,
      );
    }
  }

}

// --------------------------------------------------------------------------
// --- Synchronized Arrays Registry
// --------------------------------------------------------------------------

const syncArrays = new Map<string, SyncArray<unknown, unknown>>();

// Remark: lookup for current project

function currentSyncArray<K, A>(array: Array<K, A>): SyncArray<K, A> {
  let st = syncArrays.get(array.name) as SyncArray<K, A> | undefined;
  if (!st) {
    st = new SyncArray(array);
    syncArrays.set(array.name, st as SyncArray<unknown, unknown>);
  }
  return st;
}

Server.onShutdown(() => {
  syncArrays.forEach((st) => st.offline());
  syncArrays.clear();
});

// --------------------------------------------------------------------------
// --- Synchronized Array Hooks
// --------------------------------------------------------------------------

/** Force a Synchronized Array to reload. */
export function reloadArray<K, A>(arr: Array<K, A>): void {
  currentSyncArray(arr).reload();
}

/** Access to Synchronized Array elements. */
export interface ArrayProxy<K, A> {
  length: number;
  getData(elt: K | undefined): (A | undefined);
  forEach(fn: (row: A, elt: K) => void): void;
}

// --- Utility functions

function arrayGet<K, A>(
  model: CompactModel<K, A>,
  elt: K | undefined,
  _stamp: number,
): A | undefined {
  return elt ? model.getData(elt) : undefined;
}

function arrayProxy<K, A>(
  model: CompactModel<K, A>,
  _stamp: number,
): ArrayProxy<K, A> {
  return {
    length: model.length(),
    getData: (elt) => elt ? model.getData(elt) : undefined,
    forEach: (fn) => model.forEach((r) => fn(r, model.getkey(r))),
  };
}

// ---- Hooks

/**
   Use Synchronized Array as a low level, ready to use, Table Compact Model.

   Warning: to be in sync with the array, one shall subscribe to model events,
   eg. by using `useModel()` hook, like `<Table/>` element does.
 */
export function useSyncArrayModel<K, A>(
  arr: Array<K, A>
): CompactModel<K, A> {
  Server.useStatus();
  const st = currentSyncArray(arr);
  Server.useSignal(arr.signal, st.fetch);
  st.online();
  return st.model;
}

/** Use Synchronized Array as a data array. */
export function useSyncArrayData<K, A>(arr: Array<K, A>): A[]
{
  return useSyncArrayModel(arr).getArray();
}

/** Use Synchronized Array element. */
export function useSyncArrayElt<K, A>(
  arr: Array<K, A>,
  elt: K | undefined,
): A | undefined {
  const model = useSyncArrayModel(arr);
  const stamp = useModel(model);
  return React.useMemo(
    () => arrayGet(model, elt, stamp),
    [model, elt, stamp]
  );
}

/** Use Synchronized Array as an element data getter. */
export function useSyncArrayGetter<K, A>(
  arr: Array<K, A>
): (elt: K | undefined) => (A | undefined) {
  const model = useSyncArrayModel(arr);
  const stamp = useModel(model);
  return React.useCallback(
    (elt) => arrayGet(model, elt, stamp),
    [model, stamp]
  );
}

/** Use Synchronized Array as an array proxy. */
export function useSyncArrayProxy<K, A>(
  arr: Array<K, A>
): ArrayProxy<K, A> {
  const model = useSyncArrayModel<K, A>(arr);
  const stamp = useModel(model);
  return React.useMemo(
    () => arrayProxy(model, stamp),
    [model, stamp]
  );
}

/**
   Return the associated array model.
*/
export function getSyncArray<K, A>(
  arr: Array<K, A>,
): CompactModel<K, A> {
  const st = currentSyncArray(arr);
  return st.model;
}

/**
   Link on the associated array model.
   @param onReload callback on reload event and update event if not specified.
   @param onUpdate callback on update event.
 */
export function onSyncArray<K, A>(
  arr: Array<K, A>,
  onReload?: () => void,
  onUpdate?: () => void,
): Client {
  const st = currentSyncArray(arr);
  return st.model.link(onReload, onUpdate);
}

// --------------------------------------------------------------------------
// --- Selection
// --------------------------------------------------------------------------

/** An AST location.
 *
 *  Properties [[function]] and [[marker]] are optional,
 *  but at least one of the two must be set.
 */
export type Location = {
  fct?: string;
  marker?: Ast.marker;
};

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
export type HistorySelectActions = 'HISTORY_PREV' | 'HISTORY_NEXT';

/** A selection of multiple locations. */
export interface MultipleSelection {
  /** Name of the multiple selection.  */
  name: string;
  /** Explanatory description of the multiple selection.  */
  title: string;
  /** The index of the current selected location in [[allSelections]]. */
  index: number;
  /** All locations forming a multiple selection. */
  allSelections: Location[];
}

/** A select action on multiple locations. */
export interface MultipleSelect {
  readonly name: string;
  readonly title: string;
  readonly index: number;
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
 * - `MULTIPLE_CYCLE` cycles between the multiple selections.
 * - `MULTIPLE_CLEAR` clears the multiple selection.
 */
export type MultipleSelectActions =
  MultipleSelect | NthSelect
  | 'MULTIPLE_PREV' | 'MULTIPLE_NEXT' | 'MULTIPLE_CYCLE' | 'MULTIPLE_CLEAR';

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
  return (
    (a as MultipleSelect).locations !== undefined &&
    (a as MultipleSelect).index !== undefined
  );
}

function isNthSelect(a: SelectionActions): a is NthSelect {
  return (a as NthSelect).index !== undefined;
}

/** Update selection to the given location. */
function selectLocation(s: Selection, location: Location): Selection {
  const [prevSelections, nextSelections] =
    s.current && s.current.fct !== location.fct ?
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
  a: 'MULTIPLE_PREV' | 'MULTIPLE_NEXT' | 'MULTIPLE_CYCLE' | 'MULTIPLE_CLEAR',
): Selection {
  switch (a) {
    case 'MULTIPLE_PREV':
    case 'MULTIPLE_NEXT':
    case 'MULTIPLE_CYCLE': {
      const idx =
        a === 'MULTIPLE_PREV' ?
          s.multiple.index - 1 :
          s.multiple.index + 1;
      const index =
        a === 'MULTIPLE_CYCLE' && idx >= s.multiple.allSelections.length ?
          0 :
          idx;
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
          name: '',
          title: '',
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
    const index = action.index > 0 ? action.index : 0;
    const selection =
      action.locations.length === 0 ? s :
        selectLocation(s, action.locations[index]);
    return {
      ...selection,
      multiple: {
        name: action.name,
        title: action.title,
        allSelections: action.locations,
        index,
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
    case 'MULTIPLE_CYCLE':
    case 'MULTIPLE_CLEAR':
      return fromMultipleSelections(s, action);
    default:
      return s;
  }
}

/** The initial selection is empty. */
const emptySelection = {
  current: undefined,
  history: {
    prevSelections: [],
    nextSelections: [],
  },
  multiple: {
    name: '',
    title: '',
    index: 0,
    allSelections: [],
  },
};

export type Hovered = Location | undefined;
export const MetaSelection = new Dome.Event<Location>('frama-c-meta-selection');
export const GlobalHovered = new GlobalState<Hovered>(undefined);
export const GlobalSelection = new GlobalState<Selection>(emptySelection);

Server.onShutdown(() => GlobalSelection.setValue(emptySelection));

export function setHovered(h: Hovered): void { GlobalHovered.setValue(h); }
export function useHovered(): [Hovered, (h: Hovered) => void] {
  return useGlobalState(GlobalHovered);
}

export function setSelection(location: Location, meta = false): void {
  const s = GlobalSelection.getValue();
  GlobalSelection.setValue(reducer(s, { location }));
  if (meta) MetaSelection.emit(location);
}

/** Current selection. */
export function useSelection(): [Selection, (a: SelectionActions) => void] {
  const [current, setCurrent] = useGlobalState(GlobalSelection);
  const callback = React.useCallback((action) => {
    setCurrent(reducer(current, action));
    if (isMultipleSelect(action)) {
      const l = action.locations.length;
      const markers =
        (l > 1) ? `${l} markers selected, listed in the 'Locations' panel` :
          (l === 1) ? `1 marker selected` : `no markers selected`;
      const text = `${action.name}: ${markers}`;
      Status.setMessage({ text, title: action.title, kind: 'success' });
    }
  }, [current, setCurrent]);
  return [current, callback];
}

/** Resets the selected locations. */
export async function resetSelection(): Promise<void> {
  GlobalSelection.setValue(emptySelection);
  if (Server.isRunning()) {
    try {
      const main = await Server.send(Ast.getMainFunction, {});
      // If the selection has already been modified, do not change it.
      if (main && GlobalSelection.getValue() === emptySelection) {
        GlobalSelection.setValue({ ...emptySelection, current: { fct: main } });
      }
    } catch (err) {
      if (err) D.warn('Request error', err);
    }
  }
}

// --------------------------------------------------------------------------
// --- Markers
// --------------------------------------------------------------------------

export type attributes = Ast.markerAttributesData;

/** Access the marker attributes from AST. */
export function useMarker(marker: Ast.marker | undefined): attributes {
  const marks = useSyncArrayElt(Ast.markerAttributes, marker);
  return marks ?? Ast.markerAttributesDataDefault;
}

// --------------------------------------------------------------------------
// --- General Synchro
// --------------------------------------------------------------------------

Server.onReady(() => {
  if (GlobalSelection.getValue() === emptySelection)
    resetSelection();
});

// --------------------------------------------------------------------------
