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
   Eva General Services
   @packageDocumentation
   @module frama-c/plugins/eva/api/general
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
//@ts-ignore
import { byTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tagDefault } from 'frama-c/kernel/api/data';

/** State of the computation of Eva Analysis. */
export type computationStateType =
  "not_computed" | "computing" | "computed" | "aborted";

/** Decoder for `computationStateType` */
export const jComputationStateType: Json.Decoder<computationStateType> =
  Json.jUnion<"not_computed" | "computing" | "computed" | "aborted">(
    Json.jTag("not_computed"),
    Json.jTag("computing"),
    Json.jTag("computed"),
    Json.jTag("aborted"),
  );

/** Natural order for `computationStateType` */
export const byComputationStateType: Compare.Order<computationStateType> =
  Compare.structural;

/** Default value for `computationStateType` */
export const computationStateTypeDefault: computationStateType =
  "not_computed";

/** Signal for state [`computationState`](#computationstate)  */
export const signalComputationState: Server.Signal = {
  name: 'plugins.eva.general.signalComputationState',
};

const getComputationState_internal: Server.GetRequest<
  null,
  computationStateType
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getComputationState',
  input: Json.jNull,
  output: jComputationStateType,
  signals: [],
};
/** Getter for state [`computationState`](#computationstate)  */
export const getComputationState: Server.GetRequest<
  null,
  computationStateType
  >= getComputationState_internal;

const computationState_internal: State.Value<computationStateType> = {
  name: 'plugins.eva.general.computationState',
  signal: signalComputationState,
  getter: getComputationState,
};
/** The current computation state of the analysis. */
export const computationState: State.Value<computationStateType> = computationState_internal;

/** Callee function and caller stmt */
export type CallSite = { call: decl, stmt: marker };

/** Decoder for `CallSite` */
export const jCallSite: Json.Decoder<CallSite> =
  Json.jObject({ call: jDecl, stmt: jMarker,});

/** Natural order for `CallSite` */
export const byCallSite: Compare.Order<CallSite> =
  Compare.byFields
    <{ call: decl, stmt: marker }>({
    call: byDecl,
    stmt: byMarker,
  });

/** Default value for `CallSite` */
export const CallSiteDefault: CallSite =
  { call: declDefault, stmt: markerDefault };

const getCallers_internal: Server.GetRequest<decl,CallSite[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getCallers',
  input: jDecl,
  output: Json.jArray(jCallSite),
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Get the list of call sites for a function */
export const getCallers: Server.GetRequest<decl,CallSite[]>= getCallers_internal;

const getCallees_internal: Server.GetRequest<marker,decl[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getCallees',
  input: jMarker,
  output: Json.jArray(jDecl),
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Return the functions pointed to by a function pointer */
export const getCallees: Server.GetRequest<marker,decl[]>= getCallees_internal;

/** Data for array rows [`functions`](#functions)  */
export interface functionsData {
  /** Entry identifier. */
  key: Json.key<'#functions'>;
  /** Has the function been analyzed by Eva */
  eva_analyzed?: boolean;
}

/** Decoder for `functionsData` */
export const jFunctionsData: Json.Decoder<functionsData> =
  Json.jObject({
    key: Json.jKey<'#functions'>('#functions'),
    eva_analyzed: Json.jOption(Json.jBoolean),
  });

/** Natural order for `functionsData` */
export const byFunctionsData: Compare.Order<functionsData> =
  Compare.byFields
    <{ key: Json.key<'#functions'>, eva_analyzed?: boolean }>({
    key: Compare.string,
    eva_analyzed: Compare.defined(Compare.boolean),
  });

/** Signal for array [`functions`](#functions)  */
export const signalFunctions: Server.Signal = {
  name: 'plugins.eva.general.signalFunctions',
};

const reloadFunctions_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.reloadFunctions',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`functions`](#functions)  */
export const reloadFunctions: Server.GetRequest<null,null>= reloadFunctions_internal;

const fetchFunctions_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#functions'>[],
    updated: functionsData[], pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.fetchFunctions',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(Json.jKey<'#functions'>('#functions')),
            updated: Json.jArray(jFunctionsData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#functions'>[],
    updated: functionsData[], pending: number }
  >= fetchFunctions_internal;

const functions_internal: State.Array<Json.key<'#functions'>,functionsData> = {
  name: 'plugins.eva.general.functions',
  getkey: ((d:functionsData) => d.key),
  signal: signalFunctions,
  fetch: fetchFunctions,
  reload: reloadFunctions,
  order: byFunctionsData,
};
/** AST Functions */
export const functions: State.Array<Json.key<'#functions'>,functionsData> = functions_internal;

/** Default value for `functionsData` */
export const functionsDataDefault: functionsData =
  { key: Json.jKey<'#functions'>('#functions')(''), eva_analyzed: undefined };

/** Unreachable and non terminating statements. */
export interface deadCode {
  /** List of statements reached by the analysis. */
  reached: marker[];
  /** List of unreachable statements. */
  unreachable: marker[];
  /** List of reachable but non terminating statements. */
  nonTerminating: marker[];
}

/** Decoder for `deadCode` */
export const jDeadCode: Json.Decoder<deadCode> =
  Json.jObject({
    reached: Json.jArray(jMarker),
    unreachable: Json.jArray(jMarker),
    nonTerminating: Json.jArray(jMarker),
  });

/** Natural order for `deadCode` */
export const byDeadCode: Compare.Order<deadCode> =
  Compare.byFields
    <{ reached: marker[], unreachable: marker[], nonTerminating: marker[] }>({
    reached: Compare.array(byMarker),
    unreachable: Compare.array(byMarker),
    nonTerminating: Compare.array(byMarker),
  });

/** Default value for `deadCode` */
export const deadCodeDefault: deadCode =
  { reached: [], unreachable: [], nonTerminating: [] };

const getDeadCode_internal: Server.GetRequest<decl,deadCode | undefined> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getDeadCode',
  input: jDecl,
  output: Json.jOption(jDeadCode),
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Get the lists of unreachable and of non terminating statements in a function */
export const getDeadCode: Server.GetRequest<decl,deadCode | undefined>= getDeadCode_internal;

/** Taint status of logical properties */
export enum taintStatus {
  /** **Not computed:**
      the Eva taint domain has not been enabled, or the Eva analysis has not been run */
  not_computed = 'not_computed',
  /** **Error:**
      the memory zone on which this property depends could not be computed */
  error = 'error',
  /** **Not applicable:** no taint for this kind of property */
  not_applicable = 'not_applicable',
  /** **Direct taint:**
      this property is related to a memory location that can be affected by an attacker */
  direct_taint = 'direct_taint',
  /** **Indirect taint:**
      this property is related to a memory location whose assignment depends on path conditions that can be affected by an attacker */
  indirect_taint = 'indirect_taint',
  /** **Untainted property:** this property is safe */
  not_tainted = 'not_tainted',
}

/** Decoder for `taintStatus` */
export const jTaintStatus: Json.Decoder<taintStatus> =
  Json.jEnum(taintStatus);

/** Natural order for `taintStatus` */
export const byTaintStatus: Compare.Order<taintStatus> =
  Compare.byEnum(taintStatus);

/** Default value for `taintStatus` */
export const taintStatusDefault: taintStatus = taintStatus.not_computed;

const taintStatusTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.taintStatusTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const taintStatusTags: Server.GetRequest<null,tag[]>= taintStatusTags_internal;

/** Lvalue taint status */
export interface LvalueTaints {
  /** tainted lvalue */
  lval: marker;
  /** taint status */
  taint: taintStatus;
}

/** Decoder for `LvalueTaints` */
export const jLvalueTaints: Json.Decoder<LvalueTaints> =
  Json.jObject({ lval: jMarker, taint: jTaintStatus,});

/** Natural order for `LvalueTaints` */
export const byLvalueTaints: Compare.Order<LvalueTaints> =
  Compare.byFields
    <{ lval: marker, taint: taintStatus }>({
    lval: byMarker,
    taint: byTaintStatus,
  });

/** Default value for `LvalueTaints` */
export const LvalueTaintsDefault: LvalueTaints =
  { lval: markerDefault, taint: taintStatusDefault };

const taintedLvalues_internal: Server.GetRequest<decl,LvalueTaints[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.taintedLvalues',
  input: jDecl,
  output: Json.jArray(jLvalueTaints),
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Get the tainted lvalues of a given function */
export const taintedLvalues: Server.GetRequest<decl,LvalueTaints[]>= taintedLvalues_internal;

/** Data for array rows [`properties`](#properties)  */
export interface propertiesData {
  /** Entry identifier. */
  key: marker;
  /** Is the property invalid in some context of the analysis? */
  priority: boolean;
  /** Is the property tainted according to the Eva taint domain? */
  taint: taintStatus;
}

/** Decoder for `propertiesData` */
export const jPropertiesData: Json.Decoder<propertiesData> =
  Json.jObject({ key: jMarker, priority: Json.jBoolean, taint: jTaintStatus,
  });

/** Natural order for `propertiesData` */
export const byPropertiesData: Compare.Order<propertiesData> =
  Compare.byFields
    <{ key: marker, priority: boolean, taint: taintStatus }>({
    key: byMarker,
    priority: Compare.boolean,
    taint: byTaintStatus,
  });

/** Signal for array [`properties`](#properties)  */
export const signalProperties: Server.Signal = {
  name: 'plugins.eva.general.signalProperties',
};

const reloadProperties_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.reloadProperties',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`properties`](#properties)  */
export const reloadProperties: Server.GetRequest<null,null>= reloadProperties_internal;

const fetchProperties_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: marker[], updated: propertiesData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.fetchProperties',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jMarker),
            updated: Json.jArray(jPropertiesData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`properties`](#properties)  */
export const fetchProperties: Server.GetRequest<
  number,
  { reload: boolean, removed: marker[], updated: propertiesData[],
    pending: number }
  >= fetchProperties_internal;

const properties_internal: State.Array<marker,propertiesData> = {
  name: 'plugins.eva.general.properties',
  getkey: ((d:propertiesData) => d.key),
  signal: signalProperties,
  fetch: fetchProperties,
  reload: reloadProperties,
  order: byPropertiesData,
};
/** Status of Registered Properties */
export const properties: State.Array<marker,propertiesData> = properties_internal;

/** Default value for `propertiesData` */
export const propertiesDataDefault: propertiesData =
  { key: markerDefault, priority: false, taint: taintStatusDefault };

/** The alarms are counted after being grouped by these categories */
export enum alarmCategory {
  /** Integer division by zero */
  division_by_zero = 'division_by_zero',
  /** Invalid pointer dereferencing */
  mem_access = 'mem_access',
  /** Array access out of bounds */
  index_bound = 'index_bound',
  /** Invalid shift */
  shift = 'shift',
  /** Integer overflow or downcast */
  overflow = 'overflow',
  /** Uninitialized memory read */
  initialization = 'initialization',
  /** Read of a dangling pointer */
  dangling_pointer = 'dangling_pointer',
  /** Non-finite (nan or infinite) floating-point value */
  is_nan_or_infinite = 'is_nan_or_infinite',
  /** Overflow in float to int conversion */
  float_to_int = 'float_to_int',
  /** Any other alarm */
  other = 'other',
}

/** Decoder for `alarmCategory` */
export const jAlarmCategory: Json.Decoder<alarmCategory> =
  Json.jEnum(alarmCategory);

/** Natural order for `alarmCategory` */
export const byAlarmCategory: Compare.Order<alarmCategory> =
  Compare.byEnum(alarmCategory);

/** Default value for `alarmCategory` */
export const alarmCategoryDefault: alarmCategory =
  alarmCategory.division_by_zero;

const alarmCategoryTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.alarmCategoryTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const alarmCategoryTags: Server.GetRequest<null,tag[]>= alarmCategoryTags_internal;

/** Statuses count. */
export type statusesEntry =
  { valid: number, unknown: number, invalid: number };

/** Decoder for `statusesEntry` */
export const jStatusesEntry: Json.Decoder<statusesEntry> =
  Json.jObject({
    valid: Json.jNumber,
    unknown: Json.jNumber,
    invalid: Json.jNumber,
  });

/** Natural order for `statusesEntry` */
export const byStatusesEntry: Compare.Order<statusesEntry> =
  Compare.byFields
    <{ valid: number, unknown: number, invalid: number }>({
    valid: Compare.number,
    unknown: Compare.number,
    invalid: Compare.number,
  });

/** Default value for `statusesEntry` */
export const statusesEntryDefault: statusesEntry =
  { valid: 0, unknown: 0, invalid: 0 };

/** Alarm count for each alarm category. */
export type alarmEntry = { category: alarmCategory, count: number };

/** Decoder for `alarmEntry` */
export const jAlarmEntry: Json.Decoder<alarmEntry> =
  Json.jObject({ category: jAlarmCategory, count: Json.jNumber,});

/** Natural order for `alarmEntry` */
export const byAlarmEntry: Compare.Order<alarmEntry> =
  Compare.byFields
    <{ category: alarmCategory, count: number }>({
    category: byAlarmCategory,
    count: Compare.number,
  });

/** Default value for `alarmEntry` */
export const alarmEntryDefault: alarmEntry =
  { category: alarmCategoryDefault, count: 0 };

/** Statistics about an Eva analysis. */
export type programStatsType =
  { progFunCoverage: { reachable: number, dead: number },
    progStmtCoverage: { reachable: number, dead: number },
    progAlarms: alarmEntry[],
    evaEvents: { errors: number, warnings: number },
    kernelEvents: { errors: number, warnings: number },
    alarmsStatuses: statusesEntry, assertionsStatuses: statusesEntry,
    precondsStatuses: statusesEntry };

/** Decoder for `programStatsType` */
export const jProgramStatsType: Json.Decoder<programStatsType> =
  Json.jObject({
    progFunCoverage: Json.jObject({
                       reachable: Json.jNumber,
                       dead: Json.jNumber,
                     }),
    progStmtCoverage: Json.jObject({
                        reachable: Json.jNumber,
                        dead: Json.jNumber,
                      }),
    progAlarms: Json.jArray(jAlarmEntry),
    evaEvents: Json.jObject({ errors: Json.jNumber, warnings: Json.jNumber,}),
    kernelEvents: Json.jObject({
                    errors: Json.jNumber,
                    warnings: Json.jNumber,
                  }),
    alarmsStatuses: jStatusesEntry,
    assertionsStatuses: jStatusesEntry,
    precondsStatuses: jStatusesEntry,
  });

/** Natural order for `programStatsType` */
export const byProgramStatsType: Compare.Order<programStatsType> =
  Compare.byFields
    <{ progFunCoverage: { reachable: number, dead: number },
       progStmtCoverage: { reachable: number, dead: number },
       progAlarms: alarmEntry[],
       evaEvents: { errors: number, warnings: number },
       kernelEvents: { errors: number, warnings: number },
       alarmsStatuses: statusesEntry, assertionsStatuses: statusesEntry,
       precondsStatuses: statusesEntry }>({
    progFunCoverage: Compare.byFields
                       <{ reachable: number, dead: number }>({
                       reachable: Compare.number,
                       dead: Compare.number,
                     }),
    progStmtCoverage: Compare.byFields
                        <{ reachable: number, dead: number }>({
                        reachable: Compare.number,
                        dead: Compare.number,
                      }),
    progAlarms: Compare.array(byAlarmEntry),
    evaEvents: Compare.byFields
                 <{ errors: number, warnings: number }>({
                 errors: Compare.number,
                 warnings: Compare.number,
               }),
    kernelEvents: Compare.byFields
                    <{ errors: number, warnings: number }>({
                    errors: Compare.number,
                    warnings: Compare.number,
                  }),
    alarmsStatuses: byStatusesEntry,
    assertionsStatuses: byStatusesEntry,
    precondsStatuses: byStatusesEntry,
  });

/** Default value for `programStatsType` */
export const programStatsTypeDefault: programStatsType =
  { progFunCoverage: { reachable: 0, dead: 0 },
    progStmtCoverage: { reachable: 0, dead: 0 }, progAlarms: [],
    evaEvents: { errors: 0, warnings: 0 },
    kernelEvents: { errors: 0, warnings: 0 },
    alarmsStatuses: statusesEntryDefault,
    assertionsStatuses: statusesEntryDefault,
    precondsStatuses: statusesEntryDefault };

/** Signal for state [`programStats`](#programstats)  */
export const signalProgramStats: Server.Signal = {
  name: 'plugins.eva.general.signalProgramStats',
};

const getProgramStats_internal: Server.GetRequest<null,programStatsType> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getProgramStats',
  input: Json.jNull,
  output: jProgramStatsType,
  signals: [],
};
/** Getter for state [`programStats`](#programstats)  */
export const getProgramStats: Server.GetRequest<null,programStatsType>= getProgramStats_internal;

const programStats_internal: State.Value<programStatsType> = {
  name: 'plugins.eva.general.programStats',
  signal: signalProgramStats,
  getter: getProgramStats,
};
/** Statistics about the last Eva analysis for the whole program */
export const programStats: State.Value<programStatsType> = programStats_internal;

/** Data for array rows [`functionStats`](#functionstats)  */
export interface functionStatsData {
  /** Entry identifier. */
  key: decl;
  /** Function name */
  fctName: string;
  /** Coverage of the Eva analysis */
  coverage: { reachable: number, dead: number };
  /** Alarms raised by the Eva analysis by category */
  alarmCount: alarmEntry[];
  /** Alarms statuses emitted by the Eva analysis */
  alarmStatuses: statusesEntry;
}

/** Decoder for `functionStatsData` */
export const jFunctionStatsData: Json.Decoder<functionStatsData> =
  Json.jObject({
    key: jDecl,
    fctName: Json.jString,
    coverage: Json.jObject({ reachable: Json.jNumber, dead: Json.jNumber,}),
    alarmCount: Json.jArray(jAlarmEntry),
    alarmStatuses: jStatusesEntry,
  });

/** Natural order for `functionStatsData` */
export const byFunctionStatsData: Compare.Order<functionStatsData> =
  Compare.byFields
    <{ key: decl, fctName: string,
       coverage: { reachable: number, dead: number },
       alarmCount: alarmEntry[], alarmStatuses: statusesEntry }>({
    key: byDecl,
    fctName: Compare.alpha,
    coverage: Compare.byFields
                <{ reachable: number, dead: number }>({
                reachable: Compare.number,
                dead: Compare.number,
              }),
    alarmCount: Compare.array(byAlarmEntry),
    alarmStatuses: byStatusesEntry,
  });

/** Signal for array [`functionStats`](#functionstats)  */
export const signalFunctionStats: Server.Signal = {
  name: 'plugins.eva.general.signalFunctionStats',
};

const reloadFunctionStats_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.reloadFunctionStats',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`functionStats`](#functionstats)  */
export const reloadFunctionStats: Server.GetRequest<null,null>= reloadFunctionStats_internal;

const fetchFunctionStats_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: decl[], updated: functionStatsData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.fetchFunctionStats',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jDecl),
            updated: Json.jArray(jFunctionStatsData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`functionStats`](#functionstats)  */
export const fetchFunctionStats: Server.GetRequest<
  number,
  { reload: boolean, removed: decl[], updated: functionStatsData[],
    pending: number }
  >= fetchFunctionStats_internal;

const functionStats_internal: State.Array<decl,functionStatsData> = {
  name: 'plugins.eva.general.functionStats',
  getkey: ((d:functionStatsData) => d.key),
  signal: signalFunctionStats,
  fetch: fetchFunctionStats,
  reload: reloadFunctionStats,
  order: byFunctionStatsData,
};
/** Statistics about the last Eva analysis for each function */
export const functionStats: State.Array<decl,functionStatsData> = functionStats_internal;

/** Default value for `functionStatsData` */
export const functionStatsDataDefault: functionStatsData =
  { key: declDefault, fctName: '', coverage: { reachable: 0, dead: 0 },
    alarmCount: [], alarmStatuses: statusesEntryDefault };

const getStates_internal: Server.GetRequest<
  [ marker, boolean ],
  [ string, string, string ][]
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getStates',
  input: Json.jPair( jMarker, Json.jBoolean,),
  output: Json.jArray(
            Json.jTriple( Json.jString, Json.jString, Json.jString,)),
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Get the domain states about the given marker */
export const getStates: Server.GetRequest<
  [ marker, boolean ],
  [ string, string, string ][]
  >= getStates_internal;

/* ------------------------------------- */
