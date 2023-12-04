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

/* --- Generated Frama-C Server API --- */

/**
   WP Interactive Prover
   @packageDocumentation
   @module frama-c/plugins/wp/api/tip
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
import { byText } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jText } from 'frama-c/kernel/api/data';
//@ts-ignore
import { text } from 'frama-c/kernel/api/data';
//@ts-ignore
import { textDefault } from 'frama-c/kernel/api/data';
//@ts-ignore
import { byGoal } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { byProver } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { byResult } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { goal } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { goalDefault } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { jGoal } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { jProver } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { jResult } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { prover } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { proverDefault } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { result } from 'frama-c/plugins/wp/api';
//@ts-ignore
import { resultDefault } from 'frama-c/plugins/wp/api';

/** Proof Status has changed */
export const proofStatus: Server.Signal = {
  name: 'plugins.wp.tip.proofStatus',
};

/** Proof Node index */
export type node = Json.index<'#node'>;

/** Decoder for `node` */
export const jNode: Json.Decoder<node> = Json.jIndex<'#node'>('#node');

/** Natural order for `node` */
export const byNode: Compare.Order<node> = Compare.number;

/** Default value for `node` */
export const nodeDefault: node = Json.jIndex<'#node'>('#node')(-1);

const getNodeInfos_internal: Server.GetRequest<
  node,
  { result: string, proved: boolean, pending: number, size: number,
    stats: string, results: [ prover, result ][], tactic: string,
    children: [ string, node ][] }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getNodeInfos',
  input: jNode,
  output: Json.jObject({
            result: Json.jString,
            proved: Json.jBoolean,
            pending: Json.jNumber,
            size: Json.jNumber,
            stats: Json.jString,
            results: Json.jArray(Json.jPair( jProver, jResult,)),
            tactic: Json.jString,
            children: Json.jArray(Json.jPair( Json.jString, jNode,)),
          }),
  signals: [ { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Proof node information */
export const getNodeInfos: Server.GetRequest<
  node,
  { result: string, proved: boolean, pending: number, size: number,
    stats: string, results: [ prover, result ][], tactic: string,
    children: [ string, node ][] }
  >= getNodeInfos_internal;

const getProofState_internal: Server.GetRequest<
  goal,
  { current: node, path: node[], index: number, pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getProofState',
  input: jGoal,
  output: Json.jObject({
            current: jNode,
            path: Json.jArray(jNode),
            index: Json.jNumber,
            pending: Json.jNumber,
          }),
  signals: [ { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Current Proof Status of a Goal */
export const getProofState: Server.GetRequest<
  goal,
  { current: node, path: node[], index: number, pending: number }
  >= getProofState_internal;

const goForward_internal: Server.SetRequest<goal,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.goForward',
  input: jGoal,
  output: Json.jNull,
  signals: [],
};
/** Go to to first pending node, or root if none */
export const goForward: Server.SetRequest<goal,null>= goForward_internal;

const goToRoot_internal: Server.SetRequest<goal,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.goToRoot',
  input: jGoal,
  output: Json.jNull,
  signals: [],
};
/** Go to root of proof tree */
export const goToRoot: Server.SetRequest<goal,null>= goToRoot_internal;

const goToIndex_internal: Server.SetRequest<[ goal, number ],null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.goToIndex',
  input: Json.jPair( jGoal, Json.jNumber,),
  output: Json.jNull,
  signals: [],
};
/** Go to k-th pending node of proof tree */
export const goToIndex: Server.SetRequest<[ goal, number ],null>= goToIndex_internal;

const goToNode_internal: Server.SetRequest<node,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.goToNode',
  input: jNode,
  output: Json.jNull,
  signals: [],
};
/** Set current node of associated proof tree */
export const goToNode: Server.SetRequest<node,null>= goToNode_internal;

const removeNode_internal: Server.SetRequest<node,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.removeNode',
  input: jNode,
  output: Json.jNull,
  signals: [],
};
/** Remove node from tree and go to parent */
export const removeNode: Server.SetRequest<node,null>= removeNode_internal;

/** Proof part marker */
export type part = Json.key<'#part'>;

/** Decoder for `part` */
export const jPart: Json.Decoder<part> = Json.jKey<'#part'>('#part');

/** Natural order for `part` */
export const byPart: Compare.Order<part> = Compare.string;

/** Default value for `part` */
export const partDefault: part = Json.jKey<'#part'>('#part')('');

/** Term marker */
export type term = Json.key<'#term'>;

/** Decoder for `term` */
export const jTerm: Json.Decoder<term> = Json.jKey<'#term'>('#term');

/** Natural order for `term` */
export const byTerm: Compare.Order<term> = Compare.string;

/** Default value for `term` */
export const termDefault: term = Json.jKey<'#term'>('#term')('');

/** Updated TIP printer */
export const printStatus: Server.Signal = {
  name: 'plugins.wp.tip.printStatus',
};

/** Integer constants format */
export type iformat = "dec" | "hex" | "bin";

/** Decoder for `iformat` */
export const jIformat: Json.Decoder<iformat> =
  Json.jUnion<"dec" | "hex" | "bin">(
    Json.jTag("dec"),
    Json.jTag("hex"),
    Json.jTag("bin"),
  );

/** Natural order for `iformat` */
export const byIformat: Compare.Order<iformat> = Compare.structural;

/** Default value for `iformat` */
export const iformatDefault: iformat = "dec";

/** Real constants format */
export type rformat = "ratio" | "float" | "double";

/** Decoder for `rformat` */
export const jRformat: Json.Decoder<rformat> =
  Json.jUnion<"ratio" | "float" | "double">(
    Json.jTag("ratio"),
    Json.jTag("float"),
    Json.jTag("double"),
  );

/** Natural order for `rformat` */
export const byRformat: Compare.Order<rformat> = Compare.structural;

/** Default value for `rformat` */
export const rformatDefault: rformat = "ratio";

const printSequent_internal: Server.GetRequest<
  { node?: node, indent?: number, margin?: number, iformat?: iformat,
    rformat?: rformat, autofocus?: boolean, unmangled?: boolean },
  text
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.printSequent',
  input: Json.jObject({
           node: Json.jOption(jNode),
           indent: Json.jOption(Json.jNumber),
           margin: Json.jOption(Json.jNumber),
           iformat: Json.jOption(jIformat),
           rformat: Json.jOption(jRformat),
           autofocus: Json.jOption(Json.jBoolean),
           unmangled: Json.jOption(Json.jBoolean),
         }),
  output: jText,
  signals: [ { name: 'plugins.wp.tip.printStatus' } ],
};
/** Pretty-print the associated node */
export const printSequent: Server.GetRequest<
  { node?: node, indent?: number, margin?: number, iformat?: iformat,
    rformat?: rformat, autofocus?: boolean, unmangled?: boolean },
  text
  >= printSequent_internal;

const clearSelection_internal: Server.SetRequest<node,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearSelection',
  input: jNode,
  output: Json.jNull,
  signals: [],
};
/** Reset node selection */
export const clearSelection: Server.SetRequest<node,null>= clearSelection_internal;

const setSelection_internal: Server.SetRequest<
  { node: node, part?: part, term?: term, extend?: boolean },
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.setSelection',
  input: Json.jObject({
           node: jNode,
           part: Json.jOption(jPart),
           term: Json.jOption(jTerm),
           extend: Json.jOption(Json.jBoolean),
         }),
  output: Json.jNull,
  signals: [],
};
/** Set node selection */
export const setSelection: Server.SetRequest<
  { node: node, part?: part, term?: term, extend?: boolean },
  null
  >= setSelection_internal;

/* ------------------------------------- */
