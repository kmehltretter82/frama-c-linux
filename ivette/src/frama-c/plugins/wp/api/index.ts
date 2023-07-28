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
import { byFct } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { byMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { fct } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { fctDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jFct } from 'frama-c/kernel/api/ast';
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

const getAvailableProvers_internal: Server.GetRequest<null,prover[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.getAvailableProvers',
  input:  Json.jNull,
  output: Json.jArray(jProver),
  signals: [],
};
/** Returns the list of configured provers from why3 */
export const getAvailableProvers: Server.GetRequest<null,prover[]>= getAvailableProvers_internal;

/** Data for array rows [`goals`](#goals)  */
export interface goalsData {
  /** Entry identifier. */
  wpo: Json.key<'#wpo'>;
  /** Property Marker */
  property: marker;
  /** Informal name */
  name: string;
  /** Associated function, if any */
  fct?: fct;
  /** Associated behavior, if any */
  bhv?: string;
  /** Associated axiomatic, if any */
  thy?: string;
  /** Smoke Test Goal */
  smoke: boolean;
  /** Successfull Goal */
  passed: boolean;
  /** Verdict Details */
  stats: stats;
  /** Script File */
  script?: string;
  /** Saved Script */
  saved: boolean;
}

/** Decoder for `goalsData` */
export const jGoalsData: Json.Decoder<goalsData> =
  Json.jObject({
    wpo: Json.jKey<'#wpo'>('#wpo'),
    property: jMarker,
    name: Json.jString,
    fct: Json.jOption(jFct),
    bhv: Json.jOption(Json.jString),
    thy: Json.jOption(Json.jString),
    smoke: Json.jBoolean,
    passed: Json.jBoolean,
    stats: jStats,
    script: Json.jOption(Json.jString),
    saved: Json.jBoolean,
  });

/** Natural order for `goalsData` */
export const byGoalsData: Compare.Order<goalsData> =
  Compare.byFields
    <{ wpo: Json.key<'#wpo'>, property: marker, name: string, fct?: fct,
       bhv?: string, thy?: string, smoke: boolean, passed: boolean,
       stats: stats, script?: string, saved: boolean }>({
    wpo: Compare.string,
    property: byMarker,
    name: Compare.string,
    fct: Compare.defined(byFct),
    bhv: Compare.defined(Compare.string),
    thy: Compare.defined(Compare.string),
    smoke: Compare.boolean,
    passed: Compare.boolean,
    stats: byStats,
    script: Compare.defined(Compare.string),
    saved: Compare.boolean,
  });

/** Signal for array [`goals`](#goals)  */
export const signalGoals: Server.Signal = {
  name: 'plugins.wp.signalGoals',
};

const reloadGoals_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.reloadGoals',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`goals`](#goals)  */
export const reloadGoals: Server.GetRequest<null,null>= reloadGoals_internal;

const fetchGoals_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#wpo'>[], updated: goalsData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.fetchGoals',
  input:  Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(Json.jKey<'#wpo'>('#wpo')),
            updated: Json.jArray(jGoalsData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`goals`](#goals)  */
export const fetchGoals: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#wpo'>[], updated: goalsData[],
    pending: number }
  >= fetchGoals_internal;

const goals_internal: State.Array<Json.key<'#wpo'>,goalsData> = {
  name: 'plugins.wp.goals',
  getkey: ((d:goalsData) => d.wpo),
  signal: signalGoals,
  fetch: fetchGoals,
  reload: reloadGoals,
  order: byGoalsData,
};
/** Generated Goals */
export const goals: State.Array<Json.key<'#wpo'>,goalsData> = goals_internal;

/** Default value for `goalsData` */
export const goalsDataDefault: goalsData =
  { wpo: Json.jKey<'#wpo'>('#wpo')(''), property: markerDefault, name: '',
    fct: undefined, bhv: undefined, thy: undefined, smoke: false,
    passed: false, stats: statsDefault, script: undefined, saved: false };

/** Proof Server Activity */
export const serverActivity: Server.Signal = {
  name: 'plugins.wp.serverActivity',
};

const getScheduledTasks_internal: Server.GetRequest<
  null,
  { procs: number, active: number, done: number, todo: number }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.getScheduledTasks',
  input:  Json.jNull,
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
  name:   'plugins.wp.cancelProofTasks',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Cancel all scheduled proof tasks */
export const cancelProofTasks: Server.SetRequest<null,null>= cancelProofTasks_internal;

/* ------------------------------------- */
