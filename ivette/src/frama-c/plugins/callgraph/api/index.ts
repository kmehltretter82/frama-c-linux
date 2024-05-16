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
   Callgraph Services
   @packageDocumentation
   @module frama-c/plugins/callgraph/api
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
import { byDecl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { decl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { declDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jDecl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { byTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tagDefault } from 'frama-c/kernel/api/data';

export interface vertex {
  /** The function name of the node */
  name: string;
  /** The declaration tag of the function */
  decl: decl;
  /** whether this node is the root of a service */
  is_root: boolean;
  /** the root of this node's service */
  root: decl;
}

/** Decoder for `vertex` */
export const jVertex: Json.Decoder<vertex> =
  Json.jObject({
    name: Json.jString,
    decl: jDecl,
    is_root: Json.jBoolean,
    root: jDecl,
  });

/** Natural order for `vertex` */
export const byVertex: Compare.Order<vertex> =
  Compare.byFields
    <{ name: string, decl: decl, is_root: boolean, root: decl }>({
    name: Compare.string,
    decl: byDecl,
    is_root: Compare.boolean,
    root: byDecl,
  });

/** Default value for `vertex` */
export const vertexDefault: vertex =
  { name: '', decl: declDefault, is_root: false, root: declDefault };

/** Whether the call goes through services or not */
export enum edgeKind {
  /** a call between two services */
  inter_services = 'inter_services',
  /** a call inside a service */
  inter_functions = 'inter_functions',
  /** both cases above */
  both = 'both',
}

/** Decoder for `edgeKind` */
export const jEdgeKind: Json.Decoder<edgeKind> = Json.jEnum(edgeKind);

/** Natural order for `edgeKind` */
export const byEdgeKind: Compare.Order<edgeKind> = Compare.byEnum(edgeKind);

/** Default value for `edgeKind` */
export const edgeKindDefault: edgeKind = edgeKind.inter_services;

const edgeKindTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.callgraph.edgeKindTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const edgeKindTags: Server.GetRequest<null,tag[]>= edgeKindTags_internal;

export interface edge {
  /** src */
  src: decl;
  /** dst */
  dst: decl;
  /** kind */
  kind: edgeKind;
}

/** Decoder for `edge` */
export const jEdge: Json.Decoder<edge> =
  Json.jObject({ src: jDecl, dst: jDecl, kind: jEdgeKind,});

/** Natural order for `edge` */
export const byEdge: Compare.Order<edge> =
  Compare.byFields
    <{ src: decl, dst: decl, kind: edgeKind }>({
    src: byDecl,
    dst: byDecl,
    kind: byEdgeKind,
  });

/** Default value for `edge` */
export const edgeDefault: edge =
  { src: declDefault, dst: declDefault, kind: edgeKindDefault };

/** The callgraph of the current project */
export interface graph {
  /** vertices */
  vertices: vertex[];
  /** edges */
  edges: edge[];
}

/** Decoder for `graph` */
export const jGraph: Json.Decoder<graph> =
  Json.jObject({ vertices: Json.jArray(jVertex), edges: Json.jArray(jEdge),});

/** Natural order for `graph` */
export const byGraph: Compare.Order<graph> =
  Compare.byFields
    <{ vertices: vertex[], edges: edge[] }>({
    vertices: Compare.array(byVertex),
    edges: Compare.array(byEdge),
  });

/** Default value for `graph` */
export const graphDefault: graph = { vertices: [], edges: [] };

/** Signal for state [`callgraph`](#callgraph)  */
export const signalCallgraph: Server.Signal = {
  name: 'plugins.callgraph.signalCallgraph',
};

const getCallgraph_internal: Server.GetRequest<null,graph | undefined> = {
  kind: Server.RqKind.GET,
  name: 'plugins.callgraph.getCallgraph',
  input: Json.jNull,
  output: Json.jOption(jGraph),
  signals: [],
};
/** Getter for state [`callgraph`](#callgraph)  */
export const getCallgraph: Server.GetRequest<null,graph | undefined>= getCallgraph_internal;

const callgraph_internal: State.Value<graph | undefined> = {
  name: 'plugins.callgraph.callgraph',
  signal: signalCallgraph,
  getter: getCallgraph,
};
/** The current callgraph or an empty graph if it has not been computed yet */
export const callgraph: State.Value<graph | undefined> = callgraph_internal;

/** Signal for state [`isComputed`](#iscomputed)  */
export const signalIsComputed: Server.Signal = {
  name: 'plugins.callgraph.signalIsComputed',
};

const getIsComputed_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'plugins.callgraph.getIsComputed',
  input: Json.jNull,
  output: Json.jBoolean,
  signals: [],
};
/** Getter for state [`isComputed`](#iscomputed)  */
export const getIsComputed: Server.GetRequest<null,boolean>= getIsComputed_internal;

const isComputed_internal: State.Value<boolean> = {
  name: 'plugins.callgraph.isComputed',
  signal: signalIsComputed,
  getter: getIsComputed,
};
/** This boolean is true if the graph has been computed */
export const isComputed: State.Value<boolean> = isComputed_internal;

const compute_internal: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.callgraph.compute',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Compute the callgraph for the current project */
export const compute: Server.ExecRequest<null,null>= compute_internal;

/* ------------------------------------- */
