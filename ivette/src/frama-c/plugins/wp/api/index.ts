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
   WP Main Services
   @packageDocumentation
   @module frama-c/plugins/wp/api
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
import { byMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { decl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { declDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jDecl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { marker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { markerDefault } from 'frama-c/kernel/api/ast';

/** Proof Obligations */
export type goal = Json.key<'#wpo'>;

/** Decoder for `goal` */
export const jGoal: Json.Decoder<goal> = Json.jKey<'#wpo'>('#wpo');

/** Natural order for `goal` */
export const byGoal: Compare.Order<goal> = Compare.string;

/** Default value for `goal` */
export const goalDefault: goal = Json.jKey<'#wpo'>('#wpo')('');

/** Prover Identifier */
export type prover = Json.key<'#prover'>;

/** Decoder for `prover` */
export const jProver: Json.Decoder<prover> = Json.jKey<'#prover'>('#prover');

/** Natural order for `prover` */
export const byProver: Compare.Order<prover> = Compare.string;

/** Default value for `prover` */
export const proverDefault: prover = Json.jKey<'#prover'>('#prover')('');

/** Signal for state [`provers`](#provers)  */
export const signalProvers: Server.Signal = {
  name: 'plugins.wp.signalProvers',
};

const getProvers_internal: Server.GetRequest<null,prover[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.getProvers',
  input: Json.jNull,
  output: Json.jArray(jProver),
  signals: [],
};
/** Getter for state [`provers`](#provers)  */
export const getProvers: Server.GetRequest<null,prover[]>= getProvers_internal;

const setProvers_internal: Server.SetRequest<prover[],null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.setProvers',
  input: Json.jArray(jProver),
  output: Json.jNull,
  signals: [],
};
/** Setter for state [`provers`](#provers)  */
export const setProvers: Server.SetRequest<prover[],null>= setProvers_internal;

const provers_internal: State.State<prover[]> = {
  name: 'plugins.wp.provers',
  signal: signalProvers,
  getter: getProvers,
  setter: setProvers,
};
/** Selected Provers */
export const provers: State.State<prover[]> = provers_internal;

/** Signal for state [`process`](#process)  */
export const signalProcess: Server.Signal = {
  name: 'plugins.wp.signalProcess',
};

const getProcess_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.getProcess',
  input: Json.jNull,
  output: Json.jNumber,
  signals: [],
};
/** Getter for state [`process`](#process)  */
export const getProcess: Server.GetRequest<null,number>= getProcess_internal;

const setProcess_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.setProcess',
  input: Json.jNumber,
  output: Json.jNull,
  signals: [],
};
/** Setter for state [`process`](#process)  */
export const setProcess: Server.SetRequest<number,null>= setProcess_internal;

const process_internal: State.State<number> = {
  name: 'plugins.wp.process',
  signal: signalProcess,
  getter: getProcess,
  setter: setProcess,
};
/** Server Processes */
export const process: State.State<number> = process_internal;

/** Signal for state [`timeout`](#timeout)  */
export const signalTimeout: Server.Signal = {
  name: 'plugins.wp.signalTimeout',
};

const getTimeout_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.getTimeout',
  input: Json.jNull,
  output: Json.jNumber,
  signals: [],
};
/** Getter for state [`timeout`](#timeout)  */
export const getTimeout: Server.GetRequest<null,number>= getTimeout_internal;

const setTimeout_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.setTimeout',
  input: Json.jNumber,
  output: Json.jNull,
  signals: [],
};
/** Setter for state [`timeout`](#timeout)  */
export const setTimeout: Server.SetRequest<number,null>= setTimeout_internal;

const timeout_internal: State.State<number> = {
  name: 'plugins.wp.timeout',
  signal: signalTimeout,
  getter: getTimeout,
  setter: setTimeout,
};
/** Prover's Timeout */
export const timeout: State.State<number> = timeout_internal;

/** Data for array rows [`ProverInfos`](#proverinfos)  */
export interface ProverInfosData {
  /** Entry identifier. */
  prover: prover;
  /** Prover Name */
  name: string;
  /** Prover Version */
  version: string;
  /** Prover Full Name (description) */
  descr: string;
}

/** Decoder for `ProverInfosData` */
export const jProverInfosData: Json.Decoder<ProverInfosData> =
  Json.jObject({
    prover: jProver,
    name: Json.jString,
    version: Json.jString,
    descr: Json.jString,
  });

/** Natural order for `ProverInfosData` */
export const byProverInfosData: Compare.Order<ProverInfosData> =
  Compare.byFields
    <{ prover: prover, name: string, version: string, descr: string }>({
    prover: byProver,
    name: Compare.alpha,
    version: Compare.alpha,
    descr: Compare.alpha,
  });

/** Signal for array [`ProverInfos`](#proverinfos)  */
export const signalProverInfos: Server.Signal = {
  name: 'plugins.wp.signalProverInfos',
};

const reloadProverInfos_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.reloadProverInfos',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`ProverInfos`](#proverinfos)  */
export const reloadProverInfos: Server.GetRequest<null,null>= reloadProverInfos_internal;

const fetchProverInfos_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: prover[], updated: ProverInfosData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.fetchProverInfos',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jProver),
            updated: Json.jArray(jProverInfosData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`ProverInfos`](#proverinfos)  */
export const fetchProverInfos: Server.GetRequest<
  number,
  { reload: boolean, removed: prover[], updated: ProverInfosData[],
    pending: number }
  >= fetchProverInfos_internal;

const ProverInfos_internal: State.Array<prover,ProverInfosData> = {
  name: 'plugins.wp.ProverInfos',
  getkey: ((d:ProverInfosData) => d.prover),
  signal: signalProverInfos,
  fetch: fetchProverInfos,
  reload: reloadProverInfos,
  order: byProverInfosData,
};
/** Available Provers */
export const ProverInfos: State.Array<prover,ProverInfosData> = ProverInfos_internal;

/** Default value for `ProverInfosData` */
export const ProverInfosDataDefault: ProverInfosData =
  { prover: proverDefault, name: '', version: '', descr: '' };

/** Prover Result */
export type result =
  { descr: string, cached: boolean, verdict: string, solverTime: number,
    proverTime: number, proverSteps: number };

/** Decoder for `result` */
export const jResult: Json.Decoder<result> =
  Json.jObject({
    descr: Json.jString,
    cached: Json.jBoolean,
    verdict: Json.jString,
    solverTime: Json.jNumber,
    proverTime: Json.jNumber,
    proverSteps: Json.jNumber,
  });

/** Natural order for `result` */
export const byResult: Compare.Order<result> =
  Compare.byFields
    <{ descr: string, cached: boolean, verdict: string, solverTime: number,
       proverTime: number, proverSteps: number }>({
    descr: Compare.string,
    cached: Compare.boolean,
    verdict: Compare.string,
    solverTime: Compare.number,
    proverTime: Compare.number,
    proverSteps: Compare.number,
  });

/** Default value for `result` */
export const resultDefault: result =
  { descr: '', cached: false, verdict: '', solverTime: 0, proverTime: 0,
    proverSteps: 0 };

/** Test Status */
export type status =
  Json.key<'#NORESULT'> | Json.key<'#COMPUTING'> | Json.key<'#FAILED'> |
  Json.key<'#STEPOUT'> | Json.key<'#UNKNOWN'> | Json.key<'#VALID'> |
  Json.key<'#PASSED'> | Json.key<'#DOOMED'>;

/** Decoder for `status` */
export const jStatus: Json.Decoder<status> =
  Json.jUnion<Json.key<'#NORESULT'> | Json.key<'#COMPUTING'> |
              Json.key<'#FAILED'> | Json.key<'#STEPOUT'> |
              Json.key<'#UNKNOWN'> | Json.key<'#VALID'> |
              Json.key<'#PASSED'> | Json.key<'#DOOMED'>>(
    Json.jKey<'#NORESULT'>('#NORESULT'),
    Json.jKey<'#COMPUTING'>('#COMPUTING'),
    Json.jKey<'#FAILED'>('#FAILED'),
    Json.jKey<'#STEPOUT'>('#STEPOUT'),
    Json.jKey<'#UNKNOWN'>('#UNKNOWN'),
    Json.jKey<'#VALID'>('#VALID'),
    Json.jKey<'#PASSED'>('#PASSED'),
    Json.jKey<'#DOOMED'>('#DOOMED'),
  );

/** Natural order for `status` */
export const byStatus: Compare.Order<status> = Compare.structural;

/** Default value for `status` */
export const statusDefault: status = Json.jKey<'#NORESULT'>('#NORESULT')('');

/** Prover Result */
export type stats =
  { summary: string, tactics: number, proved: number, total: number };

/** Decoder for `stats` */
export const jStats: Json.Decoder<stats> =
  Json.jObject({
    summary: Json.jString,
    tactics: Json.jNumber,
    proved: Json.jNumber,
    total: Json.jNumber,
  });

/** Natural order for `stats` */
export const byStats: Compare.Order<stats> =
  Compare.byFields
    <{ summary: string, tactics: number, proved: number, total: number }>({
    summary: Compare.string,
    tactics: Compare.number,
    proved: Compare.number,
    total: Compare.number,
  });

/** Default value for `stats` */
export const statsDefault: stats =
  { summary: '', tactics: 0, proved: 0, total: 0 };

/** Data for array rows [`goals`](#goals)  */
export interface goalsData {
  /** Entry identifier. */
  wpo: goal;
  /** Associated Marker */
  marker: marker;
  /** Associated declaration, if any */
  scope?: decl;
  /** Property Marker */
  property: marker;
  /** Associated function name, if any */
  fct?: string;
  /** Associated behavior name, if any */
  bhv?: string;
  /** Associated axiomatic name, if any */
  thy?: string;
  /** Informal Property Name */
  name: string;
  /** Smoking (or not) goal */
  smoke: boolean;
  /** Valid or Passed goal */
  passed: boolean;
  /** Verdict, Status */
  status: status;
  /** Prover Stats Summary */
  stats: stats;
  /** Proof Tree */
  proof: boolean;
  /** Script File */
  script?: string;
  /** Saved Script */
  saved: boolean;
}

/** Decoder for `goalsData` */
export const jGoalsData: Json.Decoder<goalsData> =
  Json.jObject({
    wpo: jGoal,
    marker: jMarker,
    scope: Json.jOption(jDecl),
    property: jMarker,
    fct: Json.jOption(Json.jString),
    bhv: Json.jOption(Json.jString),
    thy: Json.jOption(Json.jString),
    name: Json.jString,
    smoke: Json.jBoolean,
    passed: Json.jBoolean,
    status: jStatus,
    stats: jStats,
    proof: Json.jBoolean,
    script: Json.jOption(Json.jString),
    saved: Json.jBoolean,
  });

/** Natural order for `goalsData` */
export const byGoalsData: Compare.Order<goalsData> =
  Compare.byFields
    <{ wpo: goal, marker: marker, scope?: decl, property: marker,
       fct?: string, bhv?: string, thy?: string, name: string,
       smoke: boolean, passed: boolean, status: status, stats: stats,
       proof: boolean, script?: string, saved: boolean }>({
    wpo: byGoal,
    marker: byMarker,
    scope: Compare.defined(byDecl),
    property: byMarker,
    fct: Compare.defined(Compare.string),
    bhv: Compare.defined(Compare.string),
    thy: Compare.defined(Compare.string),
    name: Compare.string,
    smoke: Compare.boolean,
    passed: Compare.boolean,
    status: byStatus,
    stats: byStats,
    proof: Compare.boolean,
    script: Compare.defined(Compare.string),
    saved: Compare.boolean,
  });

/** Signal for array [`goals`](#goals)  */
export const signalGoals: Server.Signal = {
  name: 'plugins.wp.signalGoals',
};

const reloadGoals_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.reloadGoals',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`goals`](#goals)  */
export const reloadGoals: Server.GetRequest<null,null>= reloadGoals_internal;

const fetchGoals_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: goal[], updated: goalsData[], pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.fetchGoals',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jGoal),
            updated: Json.jArray(jGoalsData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`goals`](#goals)  */
export const fetchGoals: Server.GetRequest<
  number,
  { reload: boolean, removed: goal[], updated: goalsData[], pending: number }
  >= fetchGoals_internal;

const goals_internal: State.Array<goal,goalsData> = {
  name: 'plugins.wp.goals',
  getkey: ((d:goalsData) => d.wpo),
  signal: signalGoals,
  fetch: fetchGoals,
  reload: reloadGoals,
  order: byGoalsData,
};
/** Generated Goals */
export const goals: State.Array<goal,goalsData> = goals_internal;

/** Default value for `goalsData` */
export const goalsDataDefault: goalsData =
  { wpo: goalDefault, marker: markerDefault, scope: undefined,
    property: markerDefault, fct: undefined, bhv: undefined, thy: undefined,
    name: '', smoke: false, passed: false, status: statusDefault,
    stats: statsDefault, proof: false, script: undefined, saved: false };

const generateRTEGuards_internal: Server.ExecRequest<marker,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.wp.generateRTEGuards',
  input: jMarker,
  output: Json.jNull,
  signals: [],
};
/** Generate RTE guards for the function */
export const generateRTEGuards: Server.ExecRequest<marker,null>= generateRTEGuards_internal;

const startProofs_internal: Server.ExecRequest<marker,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.wp.startProofs',
  input: jMarker,
  output: Json.jNull,
  signals: [],
};
/** Generate goals and run provers */
export const startProofs: Server.ExecRequest<marker,null>= startProofs_internal;

/** Proof Server Activity */
export const serverActivity: Server.Signal = {
  name: 'plugins.wp.serverActivity',
};

const getScheduledTasks_internal: Server.GetRequest<
  null,
  { procs: number, active: number, done: number, todo: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.getScheduledTasks',
  input: Json.jNull,
  output: Json.jObject({
            procs: Json.jNumber,
            active: Json.jNumber,
            done: Json.jNumber,
            todo: Json.jNumber,
          }),
  signals: [ { name: 'plugins.wp.serverActivity' } ],
};
/** Scheduled tasks in proof server */
export const getScheduledTasks: Server.GetRequest<
  null,
  { procs: number, active: number, done: number, todo: number }
  >= getScheduledTasks_internal;

const cancelProofTasks_internal: Server.SetRequest<null,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.wp.cancelProofTasks',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Cancel all scheduled proof tasks */
export const cancelProofTasks: Server.SetRequest<null,null>= cancelProofTasks_internal;

/* ------------------------------------- */
