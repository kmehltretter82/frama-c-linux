/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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

/* --- Generated Frama-C Server API --- */

/**
   Dive Services
   @packageDocumentation
   @module frama-c/plugins/dive/api
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';

//@ts-ignore
import { byMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { marker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { markerDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { byTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tagDefault } from 'frama-c/kernel/api/data';

/** Parametrization of the exploration range. */
export interface range {
  /** range for the write dependencies */
  backward?: number;
  /** range for the read dependencies */
  forward?: number;
}

/** Decoder for `range` */
export const jRange: Json.Decoder<range> =
  Json.jObject({
    backward: Json.jOption(Json.jNumber),
    forward: Json.jOption(Json.jNumber),
  });

/** Natural order for `range` */
export const byRange: Compare.Order<range> =
  Compare.byFields
    <{ backward?: number, forward?: number }>({
    backward: Compare.defined(Compare.number),
    forward: Compare.defined(Compare.number),
  });

/** Default value for `range` */
export const rangeDefault: range =
  { backward: undefined, forward: undefined };

/** Global parametrization of the exploration. */
export interface explorationWindow {
  /** how far dive will explore from root nodes ; must be a finite range */
  perception: range;
  /** range beyond which the nodes must be hidden */
  horizon: range;
}

/** Decoder for `explorationWindow` */
export const jExplorationWindow: Json.Decoder<explorationWindow> =
  Json.jObject({ perception: jRange, horizon: jRange,});

/** Natural order for `explorationWindow` */
export const byExplorationWindow: Compare.Order<explorationWindow> =
  Compare.byFields
    <{ perception: range, horizon: range }>({
    perception: byRange,
    horizon: byRange,
  });

/** Default value for `explorationWindow` */
export const explorationWindowDefault: explorationWindow =
  { perception: rangeDefault, horizon: rangeDefault };

/** A node identifier in the graph */
export type nodeId = number;

/** Decoder for `nodeId` */
export const jNodeId: Json.Decoder<nodeId> = Json.jNumber;

/** Natural order for `nodeId` */
export const byNodeId: Compare.Order<nodeId> = Compare.number;

/** Default value for `nodeId` */
export const nodeIdDefault: nodeId = 0;

/** callsite */
export type callsite = { fun: string, instr: number | "global" };

/** Decoder for `callsite` */
export const jCallsite: Json.Decoder<callsite> =
  Json.jObject({
    fun: Json.jString,
    instr: Json.jUnion<number | "global">( Json.jNumber, Json.jTag("global"),
           ),
  });

/** Natural order for `callsite` */
export const byCallsite: Compare.Order<callsite> =
  Compare.byFields
    <{ fun: string, instr: number | "global" }>({
    fun: Compare.string,
    instr: Compare.structural,
  });

/** Default value for `callsite` */
export const callsiteDefault: callsite = { fun: '', instr: 0 };

/** The callstack context for a node */
export type callstack = callsite[];

/** Decoder for `callstack` */
export const jCallstack: Json.Decoder<callstack> = Json.jArray(jCallsite);

/** Natural order for `callstack` */
export const byCallstack: Compare.Order<callstack> =
  Compare.array(byCallsite);

/** Default value for `callstack` */
export const callstackDefault: callstack = [];

/** The description of a node locality */
export interface nodeLocality {
  /** file */
  file: string;
  /** callstack */
  callstack?: callstack;
}

/** Decoder for `nodeLocality` */
export const jNodeLocality: Json.Decoder<nodeLocality> =
  Json.jObject({ file: Json.jString, callstack: Json.jOption(jCallstack),});

/** Natural order for `nodeLocality` */
export const byNodeLocality: Compare.Order<nodeLocality> =
  Compare.byFields
    <{ file: string, callstack?: callstack }>({
    file: Compare.string,
    callstack: Compare.defined(byCallstack),
  });

/** Default value for `nodeLocality` */
export const nodeLocalityDefault: nodeLocality =
  { file: '', callstack: undefined };

/** The nature of a node */
export enum nodeKind {
  /** a single memory cell */
  scalar = 'scalar',
  /** a memory bloc containing cells */
  composite = 'composite',
  /** a set of memory locations designated by an lvalue */
  scattered = 'scattered',
  /** an unresolved memory location */
  unknown = 'unknown',
  /** an alarm emitted by Frama-C */
  alarm = 'alarm',
  /** a memory location designated by a range of adresses */
  absolute = 'absolute',
  /** a string literal */
  string = 'string',
  /** a placeholder node when an error prevented the generation process */
  error = 'error',
  /** a numeric constant literal */
  const = 'const',
}

/** Decoder for `nodeKind` */
export const jNodeKind: Json.Decoder<nodeKind> = Json.jEnum(nodeKind);

/** Natural order for `nodeKind` */
export const byNodeKind: Compare.Order<nodeKind> = Compare.byEnum(nodeKind);

/** Default value for `nodeKind` */
export const nodeKindDefault: nodeKind = nodeKind.scalar;

const nodeKindTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.dive.nodeKindTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const nodeKindTags: Server.GetRequest<null,tag[]>= nodeKindTags_internal;

/** Taint of a memory location */
export enum taint {
  /** not tainted by anything */
  untainted = 'untainted',
  /** tainted by control */
  indirect = 'indirect',
  /** tainted by data */
  direct = 'direct',
}

/** Decoder for `taint` */
export const jTaint: Json.Decoder<taint> = Json.jEnum(taint);

/** Natural order for `taint` */
export const byTaint: Compare.Order<taint> = Compare.byEnum(taint);

/** Default value for `taint` */
export const taintDefault: taint = taint.untainted;

const taintTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.dive.taintTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const taintTags: Server.GetRequest<null,tag[]>= taintTags_internal;

/** The computation state of a node read or write dependencies */
export enum exploration {
  /** all dependencies have been computed */
  yes = 'yes',
  /** some dependencies have been explored */
  partial = 'partial',
  /** dependencies have not been computed */
  no = 'no',
}

/** Decoder for `exploration` */
export const jExploration: Json.Decoder<exploration> =
  Json.jEnum(exploration);

/** Natural order for `exploration` */
export const byExploration: Compare.Order<exploration> =
  Compare.byEnum(exploration);

/** Default value for `exploration` */
export const explorationDefault: exploration = exploration.yes;

const explorationTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.dive.explorationTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const explorationTags: Server.GetRequest<null,tag[]>= explorationTags_internal;

/** A qualitative description of the range of values that this node can take. */
export enum nodeSpecialRange {
  /** no value ever computed for this node */
  empty = 'empty',
  /** this node can only have one value */
  singleton = 'singleton',
  /** this node can take almost all values of its type */
  wide = 'wide',
}

/** Decoder for `nodeSpecialRange` */
export const jNodeSpecialRange: Json.Decoder<nodeSpecialRange> =
  Json.jEnum(nodeSpecialRange);

/** Natural order for `nodeSpecialRange` */
export const byNodeSpecialRange: Compare.Order<nodeSpecialRange> =
  Compare.byEnum(nodeSpecialRange);

/** Default value for `nodeSpecialRange` */
export const nodeSpecialRangeDefault: nodeSpecialRange =
  nodeSpecialRange.empty;

const nodeSpecialRangeTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.dive.nodeSpecialRangeTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const nodeSpecialRangeTags: Server.GetRequest<null,tag[]>= nodeSpecialRangeTags_internal;

/** A qualitative or quantitative description of the range of values that this node can take. */
export type nodeRange = number | nodeSpecialRange;

/** Decoder for `nodeRange` */
export const jNodeRange: Json.Decoder<nodeRange> =
  Json.jUnion<number | nodeSpecialRange>( Json.jNumber, jNodeSpecialRange,);

/** Natural order for `nodeRange` */
export const byNodeRange: Compare.Order<nodeRange> = Compare.structural;

/** Default value for `nodeRange` */
export const nodeRangeDefault: nodeRange = 0;

export interface node {
  /** id */
  id: nodeId;
  /** label */
  label: string;
  /** nkind */
  nkind: nodeKind;
  /** locality */
  locality: nodeLocality;
  /** is_root */
  is_root: boolean;
  /** backward_explored */
  backward_explored: exploration;
  /** forward_explored */
  forward_explored: exploration;
  /** writes */
  writes: marker[];
  /** values */
  values?: string;
  /** range */
  range: nodeRange;
  /** type */
  type?: string;
  /** taint */
  taint?: taint;
}

/** Decoder for `node` */
export const jNode: Json.Decoder<node> =
  Json.jObject({
    id: jNodeId,
    label: Json.jString,
    nkind: jNodeKind,
    locality: jNodeLocality,
    is_root: Json.jBoolean,
    backward_explored: jExploration,
    forward_explored: jExploration,
    writes: Json.jArray(jMarker),
    values: Json.jOption(Json.jString),
    range: jNodeRange,
    type: Json.jOption(Json.jString),
    taint: Json.jOption(jTaint),
  });

/** Natural order for `node` */
export const byNode: Compare.Order<node> =
  Compare.byFields
    <{ id: nodeId, label: string, nkind: nodeKind, locality: nodeLocality,
       is_root: boolean, backward_explored: exploration,
       forward_explored: exploration, writes: marker[], values?: string,
       range: nodeRange, type?: string, taint?: taint }>({
    id: byNodeId,
    label: Compare.string,
    nkind: byNodeKind,
    locality: byNodeLocality,
    is_root: Compare.boolean,
    backward_explored: byExploration,
    forward_explored: byExploration,
    writes: Compare.array(byMarker),
    values: Compare.defined(Compare.string),
    range: byNodeRange,
    type: Compare.defined(Compare.string),
    taint: Compare.defined(byTaint),
  });

/** Default value for `node` */
export const nodeDefault: node =
  { id: nodeIdDefault, label: '', nkind: nodeKindDefault,
    locality: nodeLocalityDefault, is_root: false,
    backward_explored: explorationDefault,
    forward_explored: explorationDefault, writes: [], values: undefined,
    range: nodeRangeDefault, type: undefined, taint: undefined };

/** The dependency between two nodes */
export interface dependency {
  /** id */
  id: number;
  /** src */
  src: nodeId;
  /** dst */
  dst: nodeId;
  /** dkind */
  dkind: string;
  /** origins */
  origins: marker[];
}

/** Decoder for `dependency` */
export const jDependency: Json.Decoder<dependency> =
  Json.jObject({
    id: Json.jNumber,
    src: jNodeId,
    dst: jNodeId,
    dkind: Json.jString,
    origins: Json.jArray(jMarker),
  });

/** Natural order for `dependency` */
export const byDependency: Compare.Order<dependency> =
  Compare.byFields
    <{ id: number, src: nodeId, dst: nodeId, dkind: string, origins: marker[]
       }>({
    id: Compare.number,
    src: byNodeId,
    dst: byNodeId,
    dkind: Compare.string,
    origins: Compare.array(byMarker),
  });

/** Default value for `dependency` */
export const dependencyDefault: dependency =
  { id: 0, src: nodeIdDefault, dst: nodeIdDefault, dkind: '', origins: [] };

/** A graph element, either a node or a dependency */
export type element = node | dependency;

/** Decoder for `element` */
export const jElement: Json.Decoder<element> =
  Json.jUnion<node | dependency>( jNode, jDependency,);

/** Natural order for `element` */
export const byElement: Compare.Order<element> = Compare.structural;

/** Default value for `element` */
export const elementDefault: element = nodeDefault;

/** Data for array rows [`graph`](#graph)  */
export interface graphData {
  /** Entry identifier. */
  key: Json.key<'#graph'>;
  /** a graph element */
  element: element;
}

/** Decoder for `graphData` */
export const jGraphData: Json.Decoder<graphData> =
  Json.jObject({ key: Json.jKey<'#graph'>('#graph'), element: jElement,});

/** Natural order for `graphData` */
export const byGraphData: Compare.Order<graphData> =
  Compare.byFields
    <{ key: Json.key<'#graph'>, element: element }>({
    key: Compare.string,
    element: byElement,
  });

/** Signal for array [`graph`](#graph)  */
export const signalGraph: Server.Signal = {
  name: 'plugins.dive.signalGraph',
};

const reloadGraph_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.dive.reloadGraph',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`graph`](#graph)  */
export const reloadGraph: Server.GetRequest<null,null>= reloadGraph_internal;

const fetchGraph_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#graph'>[], updated: graphData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.dive.fetchGraph',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(Json.jKey<'#graph'>('#graph')),
            updated: Json.jArray(jGraphData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`graph`](#graph)  */
export const fetchGraph: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#graph'>[], updated: graphData[],
    pending: number }
  >= fetchGraph_internal;

const graph_internal: State.Array<Json.key<'#graph'>,graphData> = {
  name: 'plugins.dive.graph',
  getkey: ((d:graphData) => d.key),
  signal: signalGraph,
  fetch: fetchGraph,
  reload: reloadGraph,
  order: byGraphData,
};
/** The graph being built as a set of vertices and edges */
export const graph: State.Array<Json.key<'#graph'>,graphData> = graph_internal;

/** Default value for `graphData` */
export const graphDataDefault: graphData =
  { key: Json.jKey<'#graph'>('#graph')(''), element: elementDefault };

const window_internal: Server.SetRequest<explorationWindow,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.dive.window',
  input: jExplorationWindow,
  output: Json.jNull,
  signals: [],
};
/** Set the exploration window */
export const window: Server.SetRequest<explorationWindow,null>= window_internal;

const clear_internal: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.dive.clear',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Erase the graph and start over with an empty one */
export const clear: Server.ExecRequest<null,null>= clear_internal;

const add_internal: Server.ExecRequest<marker,nodeId | undefined> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.dive.add',
  input: jMarker,
  output: Json.jOption(jNodeId),
  signals: [],
};
/** Add a node to the graph */
export const add: Server.ExecRequest<marker,nodeId | undefined>= add_internal;

const explore_internal: Server.ExecRequest<nodeId,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.dive.explore',
  input: jNodeId,
  output: Json.jNull,
  signals: [],
};
/** Explore the graph starting from an existing vertex */
export const explore: Server.ExecRequest<nodeId,null>= explore_internal;

const show_internal: Server.ExecRequest<nodeId,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.dive.show',
  input: jNodeId,
  output: Json.jNull,
  signals: [],
};
/** Show the dependencies of an existing vertex */
export const show: Server.ExecRequest<nodeId,null>= show_internal;

const hide_internal: Server.ExecRequest<nodeId,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.dive.hide',
  input: jNodeId,
  output: Json.jNull,
  signals: [],
};
/** Hide the dependencies of an existing vertex */
export const hide: Server.ExecRequest<nodeId,null>= hide_internal;

/* ------------------------------------- */
