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

/** Updated TIP printer */
export const printStatus: Server.Signal = {
  name: 'plugins.wp.tip.printStatus',
};

/** Proof Node index */
export type node = Json.index<'#node'>;

/** Decoder for `node` */
export const jNode: Json.Decoder<node> = Json.jIndex<'#node'>('#node');

/** Natural order for `node` */
export const byNode: Compare.Order<node> = Compare.number;

/** Default value for `node` */
export const nodeDefault: node = Json.jIndex<'#node'>('#node')(-1);

/** Tactic identifier */
export type tactic = Json.key<'#tactic'>;

/** Decoder for `tactic` */
export const jTactic: Json.Decoder<tactic> = Json.jKey<'#tactic'>('#tactic');

/** Natural order for `tactic` */
export const byTactic: Compare.Order<tactic> = Compare.string;

/** Default value for `tactic` */
export const tacticDefault: tactic = Json.jKey<'#tactic'>('#tactic')('');

const getNodeInfos_internal: Server.GetRequest<
  node,
  { title: string, proved: boolean, pending: number, size: number,
    stats: string, results: [ prover, result ][], tactic?: tactic,
    header?: string, childLabel?: string, path: node[], children: node[] }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getNodeInfos',
  input: jNode,
  output: Json.jObject({
            title: Json.jString,
            proved: Json.jBoolean,
            pending: Json.jNumber,
            size: Json.jNumber,
            stats: Json.jString,
            results: Json.jArray(Json.jPair( jProver, jResult,)),
            tactic: Json.jOption(jTactic),
            header: Json.jOption(Json.jString),
            childLabel: Json.jOption(Json.jString),
            path: Json.jArray(jNode),
            children: Json.jArray(jNode),
          }),
  signals: [ { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Proof node information */
export const getNodeInfos: Server.GetRequest<
  node,
  { title: string, proved: boolean, pending: number, size: number,
    stats: string, results: [ prover, result ][], tactic?: tactic,
    header?: string, childLabel?: string, path: node[], children: node[] }
  >= getNodeInfos_internal;

const getResult_internal: Server.GetRequest<
  { node: node, prover: prover },
  result
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getResult',
  input: Json.jObject({ node: jNode, prover: jProver,}),
  output: jResult,
  signals: [ { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Result for specified node and prover */
export const getResult: Server.GetRequest<
  { node: node, prover: prover },
  result
  >= getResult_internal;

const getProofStatus_internal: Server.GetRequest<
  { main: goal, unproved?: boolean, subtree?: boolean },
  { size: number, index: number, pending: number, current: node,
    parents: node[], tactic?: tactic, children: node[] }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getProofStatus',
  input: Json.jObject({
           main: jGoal,
           unproved: Json.jOption(Json.jBoolean),
           subtree: Json.jOption(Json.jBoolean),
         }),
  output: Json.jObject({
            size: Json.jNumber,
            index: Json.jNumber,
            pending: Json.jNumber,
            current: jNode,
            parents: Json.jArray(jNode),
            tactic: Json.jOption(jTactic),
            children: Json.jArray(jNode),
          }),
  signals: [ { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Current Proof Status of a Goal */
export const getProofStatus: Server.GetRequest<
  { main: goal, unproved?: boolean, subtree?: boolean },
  { size: number, index: number, pending: number, current: node,
    parents: node[], tactic?: tactic, children: node[] }
  >= getProofStatus_internal;

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

const clearNode_internal: Server.SetRequest<node,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearNode',
  input: jNode,
  output: Json.jNull,
  signals: [],
};
/** Cancel all node results and sub-tree (if any) */
export const clearNode: Server.SetRequest<node,null>= clearNode_internal;

const clearNodeTactic_internal: Server.SetRequest<node,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearNodeTactic',
  input: jNode,
  output: Json.jNull,
  signals: [],
};
/** Cancel node current tactic */
export const clearNodeTactic: Server.SetRequest<node,null>= clearNodeTactic_internal;

const clearParentTactic_internal: Server.SetRequest<node,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearParentTactic',
  input: jNode,
  output: Json.jNull,
  signals: [],
};
/** Cancel parent node tactic */
export const clearParentTactic: Server.SetRequest<node,null>= clearParentTactic_internal;

const clearGoal_internal: Server.SetRequest<goal,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearGoal',
  input: jGoal,
  output: Json.jNull,
  signals: [],
};
/** Remove the complete goal proof tree */
export const clearGoal: Server.SetRequest<goal,null>= clearGoal_internal;

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

const getSelection_internal: Server.GetRequest<
  node,
  { part?: part, term?: term }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getSelection',
  input: jNode,
  output: Json.jObject({
            part: Json.jOption(jPart),
            term: Json.jOption(jTerm),
          }),
  signals: [ { name: 'plugins.wp.tip.printStatus' },
             { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Get current selection in proof node */
export const getSelection: Server.GetRequest<
  node,
  { part?: part, term?: term }
  >= getSelection_internal;

const runProvers_internal: Server.SetRequest<
  { node: node, timeout?: number, provers?: prover[] },
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.runProvers',
  input: Json.jObject({
           node: jNode,
           timeout: Json.jOption(Json.jNumber),
           provers: Json.jOption(Json.jArray(jProver)),
         }),
  output: Json.jNull,
  signals: [],
};
/** Schedule provers on proof node */
export const runProvers: Server.SetRequest<
  { node: node, timeout?: number, provers?: prover[] },
  null
  >= runProvers_internal;

const killProvers_internal: Server.SetRequest<
  { node: node, provers?: prover[] },
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.killProvers',
  input: Json.jObject({
           node: jNode,
           provers: Json.jOption(Json.jArray(jProver)),
         }),
  output: Json.jNull,
  signals: [],
};
/** Interrupt running provers on proof node */
export const killProvers: Server.SetRequest<
  { node: node, provers?: prover[] },
  null
  >= killProvers_internal;

const clearProvers_internal: Server.SetRequest<
  { node: node, provers?: prover[] },
  null
  > = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearProvers',
  input: Json.jObject({
           node: jNode,
           provers: Json.jOption(Json.jArray(jProver)),
         }),
  output: Json.jNull,
  signals: [],
};
/** Remove prover results from proof node */
export const clearProvers: Server.SetRequest<
  { node: node, provers?: prover[] },
  null
  >= clearProvers_internal;

const getScriptStatus_internal: Server.GetRequest<
  goal,
  { proof: boolean, script?: string, saved: boolean }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tip.getScriptStatus',
  input: jGoal,
  output: Json.jObject({
            proof: Json.jBoolean,
            script: Json.jOption(Json.jString),
            saved: Json.jBoolean,
          }),
  signals: [ { name: 'plugins.wp.tip.proofStatus' } ],
};
/** Script Status for a given Goal */
export const getScriptStatus: Server.GetRequest<
  goal,
  { proof: boolean, script?: string, saved: boolean }
  >= getScriptStatus_internal;

const saveScript_internal: Server.SetRequest<goal,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.saveScript',
  input: jGoal,
  output: Json.jNull,
  signals: [],
};
/** Save Script for the Goal */
export const saveScript: Server.SetRequest<goal,null>= saveScript_internal;

const runScript_internal: Server.SetRequest<goal,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.runScript',
  input: jGoal,
  output: Json.jNull,
  signals: [],
};
/** Replay Saved Script for the Goal (if any) */
export const runScript: Server.SetRequest<goal,null>= runScript_internal;

const clearProofScript_internal: Server.SetRequest<goal,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.tip.clearProofScript',
  input: jGoal,
  output: Json.jNull,
  signals: [],
};
/** Clear Proof and Remove any Saved Script for the Goal */
export const clearProofScript: Server.SetRequest<goal,null>= clearProofScript_internal;

/* ------------------------------------- */
