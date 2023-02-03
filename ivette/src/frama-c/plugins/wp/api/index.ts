/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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
   WP Plugin
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
import { byMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { marker } from 'frama-c/kernel/api/ast';

/** Proof Obligations */
export type goal = Json.key<'#wpo'>;

/** Decoder for `goal` */
export const jGoal: Json.Decoder<goal> = Json.jKey<'#wpo'>('#wpo');

/** Natural order for `goal` */
export const byGoal: Compare.Order<goal> = Compare.string;

/** Prover Identifier */
export type prover = Json.key<'#prover'>;

/** Decoder for `prover` */
export const jProver: Json.Decoder<prover> = Json.jKey<'#prover'>('#prover');

/** Natural order for `prover` */
export const byProver: Compare.Order<prover> = Compare.string;

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

/** Data for array rows [`goals`](#goals)  */
export interface goalsData {
  /** Entry identifier. */
  wpo: Json.key<'#wpo'>;
  /** Property Marker */
  property: marker;
  /** Informal name */
  name: string;
  /** Associated function, if any */
  fct?: Json.key<'#fct'>;
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
  /** Prover Results */
  results: [ prover, result ][];
}

/** Decoder for `goalsData` */
export const jGoalsData: Json.Decoder<goalsData> =
  Json.jObject({
    wpo: Json.jKey<'#wpo'>('#wpo'),
    property: jMarker,
    name: Json.jString,
    fct: Json.jOption(Json.jKey<'#fct'>('#fct')),
    bhv: Json.jOption(Json.jString),
    thy: Json.jOption(Json.jString),
    smoke: Json.jBoolean,
    passed: Json.jBoolean,
    stats: jStats,
    results: Json.jArray(Json.jPair( jProver, jResult,)),
  });

/** Natural order for `goalsData` */
export const byGoalsData: Compare.Order<goalsData> =
  Compare.byFields
    <{ wpo: Json.key<'#wpo'>, property: marker, name: string,
       fct?: Json.key<'#fct'>, bhv?: string, thy?: string, smoke: boolean,
       passed: boolean, stats: stats, results: [ prover, result ][] }>({
    wpo: Compare.string,
    property: byMarker,
    name: Compare.string,
    fct: Compare.defined(Compare.string),
    bhv: Compare.defined(Compare.string),
    thy: Compare.defined(Compare.string),
    smoke: Compare.boolean,
    passed: Compare.boolean,
    stats: byStats,
    results: Compare.array(Compare.pair(byProver,byResult,)),
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
  { pending: number, updated: goalsData[], removed: Json.key<'#wpo'>[],
    reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.fetchGoals',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jNumber,
            updated: Json.jArray(jGoalsData),
            removed: Json.jArray(Json.jKey<'#wpo'>('#wpo')),
            reload: Json.jBoolean,
          }),
  signals: [],
};
/** Data fetcher for array [`goals`](#goals)  */
export const fetchGoals: Server.GetRequest<
  number,
  { pending: number, updated: goalsData[], removed: Json.key<'#wpo'>[],
    reload: boolean }
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

/* ------------------------------------- */
