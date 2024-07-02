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
  fallback: computationStateTypeDefault,
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

const compute_internal: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.eva.general.compute',
  input: Json.jNull,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** run eva analysis */
export const compute: Server.ExecRequest<null,null>= compute_internal;

const abort_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.abort',
  input: Json.jNull,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** abort eva analysis */
export const abort: Server.GetRequest<null,null>= abort_internal;

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
  fallback: [],
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Get the list of call sites for a function */
export const getCallers: Server.GetRequest<decl,CallSite[]>= getCallers_internal;

const getCallees_internal: Server.GetRequest<marker,decl[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getCallees',
  input: jMarker,
  output: Json.jArray(jDecl),
  fallback: [],
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
  fallback: null,
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
  fallback: { reload: false, removed: [], updated: [], pending: 0 },
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
  fallback: undefined,
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
  fallback: [],
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
  fallback: [],
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
  fallback: null,
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
  fallback: { reload: false, removed: [], updated: [], pending: 0 },
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
  fallback: [],
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
  fallback: programStatsTypeDefault,
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
  fallback: null,
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
  fallback: { reload: false, removed: [], updated: [], pending: 0 },
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
  fallback: [],
  signals: [ { name: 'plugins.eva.general.signalComputationState' } ],
};
/** Get the domain states about the given marker */
export const getStates: Server.GetRequest<
  [ marker, boolean ],
  [ string, string, string ][]
  >= getStates_internal;

/** Signal for state [`eva`](#eva)  */
export const signalEva: Server.Signal = {
  name: 'plugins.eva.general.signalEva',
};

const getEva_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getEva',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`eva`](#eva)  */
export const getEva: Server.GetRequest<null,boolean>= getEva_internal;

const setEva_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setEva',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`eva`](#eva)  */
export const setEva: Server.SetRequest<boolean,null>= setEva_internal;

const eva_internal: State.State<boolean> = {
  name: 'plugins.eva.general.eva',
  signal: signalEva,
  getter: getEva,
  setter: setEva,
};
/** Eva enabled */
export const eva: State.State<boolean> = eva_internal;

/** Signal for state [`precision`](#precision)  */
export const signalPrecision: Server.Signal = {
  name: 'plugins.eva.general.signalPrecision',
};

const getPrecision_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getPrecision',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`precision`](#precision)  */
export const getPrecision: Server.GetRequest<null,number>= getPrecision_internal;

const setPrecision_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setPrecision',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`precision`](#precision)  */
export const setPrecision: Server.SetRequest<number,null>= setPrecision_internal;

const precision_internal: State.State<number> = {
  name: 'plugins.eva.general.precision',
  signal: signalPrecision,
  getter: getPrecision,
  setter: setPrecision,
};
/** Precision value */
export const precision: State.State<number> = precision_internal;

/** Signal for state [`slevel`](#slevel)  */
export const signalSlevel: Server.Signal = {
  name: 'plugins.eva.general.signalSlevel',
};

const getSlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getSlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`slevel`](#slevel)  */
export const getSlevel: Server.GetRequest<null,number>= getSlevel_internal;

const setSlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setSlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`slevel`](#slevel)  */
export const setSlevel: Server.SetRequest<number,null>= setSlevel_internal;

const slevel_internal: State.State<number> = {
  name: 'plugins.eva.general.slevel',
  signal: signalSlevel,
  getter: getSlevel,
  setter: setSlevel,
};
/** slevel value */
export const slevel: State.State<number> = slevel_internal;

/** Signal for state [`main`](#main)  */
export const signalMain: Server.Signal = {
  name: 'plugins.eva.general.signalMain',
};

const getMain_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getMain',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`main`](#main)  */
export const getMain: Server.GetRequest<null,string>= getMain_internal;

const setMain_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setMain',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`main`](#main)  */
export const setMain: Server.SetRequest<string,null>= setMain_internal;

const main_internal: State.State<string> = {
  name: 'plugins.eva.general.main',
  signal: signalMain,
  getter: getMain,
  setter: setMain,
};
/** main function */
export const main: State.State<string> = main_internal;

/** Signal for state [`libEntry`](#libentry)  */
export const signalLibEntry: Server.Signal = {
  name: 'plugins.eva.general.signalLibEntry',
};

const getLibEntry_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getLibEntry',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`libEntry`](#libentry)  */
export const getLibEntry: Server.GetRequest<null,boolean>= getLibEntry_internal;

const setLibEntry_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setLibEntry',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`libEntry`](#libentry)  */
export const setLibEntry: Server.SetRequest<boolean,null>= setLibEntry_internal;

const libEntry_internal: State.State<boolean> = {
  name: 'plugins.eva.general.libEntry',
  signal: signalLibEntry,
  getter: getLibEntry,
  setter: setLibEntry,
};
/** slevel value */
export const libEntry: State.State<boolean> = libEntry_internal;

/** Signal for state [`Domains`](#domains)  */
export const signalDomains: Server.Signal = {
  name: 'plugins.eva.general.signalDomains',
};

const getDomains_internal: Server.GetRequest<null,string[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getDomains',
  input: Json.jNull,
  output: Json.jArray(Json.jString),
  fallback: [],
  signals: [],
};
/** Getter for state [`Domains`](#domains)  */
export const getDomains: Server.GetRequest<null,string[]>= getDomains_internal;

const setDomains_internal: Server.SetRequest<string[],null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setDomains',
  input: Json.jArray(Json.jString),
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`Domains`](#domains)  */
export const setDomains: Server.SetRequest<string[],null>= setDomains_internal;

const Domains_internal: State.State<string[]> = {
  name: 'plugins.eva.general.Domains',
  signal: signalDomains,
  getter: getDomains,
  setter: setDomains,
};
/** domains value */
export const Domains: State.State<string[]> = Domains_internal;

/** Signal for state [`ilevel`](#ilevel)  */
export const signalIlevel: Server.Signal = {
  name: 'plugins.eva.general.signalIlevel',
};

const getIlevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getIlevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`ilevel`](#ilevel)  */
export const getIlevel: Server.GetRequest<null,number>= getIlevel_internal;

const setIlevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setIlevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`ilevel`](#ilevel)  */
export const setIlevel: Server.SetRequest<number,null>= setIlevel_internal;

const ilevel_internal: State.State<number> = {
  name: 'plugins.eva.general.ilevel',
  signal: signalIlevel,
  getter: getIlevel,
  setter: setIlevel,
};
/** ilevel value */
export const ilevel: State.State<number> = ilevel_internal;

/** Signal for state [`MinLoopUnroll`](#minloopunroll)  */
export const signalMinLoopUnroll: Server.Signal = {
  name: 'plugins.eva.general.signalMinLoopUnroll',
};

const getMinLoopUnroll_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getMinLoopUnroll',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`MinLoopUnroll`](#minloopunroll)  */
export const getMinLoopUnroll: Server.GetRequest<null,number>= getMinLoopUnroll_internal;

const setMinLoopUnroll_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setMinLoopUnroll',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`MinLoopUnroll`](#minloopunroll)  */
export const setMinLoopUnroll: Server.SetRequest<number,null>= setMinLoopUnroll_internal;

const MinLoopUnroll_internal: State.State<number> = {
  name: 'plugins.eva.general.MinLoopUnroll',
  signal: signalMinLoopUnroll,
  getter: getMinLoopUnroll,
  setter: setMinLoopUnroll,
};
/** Min loop unroll value */
export const MinLoopUnroll: State.State<number> = MinLoopUnroll_internal;

/** Signal for state [`AutoLoopUnroll`](#autoloopunroll)  */
export const signalAutoLoopUnroll: Server.Signal = {
  name: 'plugins.eva.general.signalAutoLoopUnroll',
};

const getAutoLoopUnroll_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getAutoLoopUnroll',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`AutoLoopUnroll`](#autoloopunroll)  */
export const getAutoLoopUnroll: Server.GetRequest<null,number>= getAutoLoopUnroll_internal;

const setAutoLoopUnroll_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setAutoLoopUnroll',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`AutoLoopUnroll`](#autoloopunroll)  */
export const setAutoLoopUnroll: Server.SetRequest<number,null>= setAutoLoopUnroll_internal;

const AutoLoopUnroll_internal: State.State<number> = {
  name: 'plugins.eva.general.AutoLoopUnroll',
  signal: signalAutoLoopUnroll,
  getter: getAutoLoopUnroll,
  setter: setAutoLoopUnroll,
};
/** Auto loop unroll value */
export const AutoLoopUnroll: State.State<number> = AutoLoopUnroll_internal;

/** Signal for state [`WideningDelay`](#wideningdelay)  */
export const signalWideningDelay: Server.Signal = {
  name: 'plugins.eva.general.signalWideningDelay',
};

const getWideningDelay_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getWideningDelay',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`WideningDelay`](#wideningdelay)  */
export const getWideningDelay: Server.GetRequest<null,number>= getWideningDelay_internal;

const setWideningDelay_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setWideningDelay',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`WideningDelay`](#wideningdelay)  */
export const setWideningDelay: Server.SetRequest<number,null>= setWideningDelay_internal;

const WideningDelay_internal: State.State<number> = {
  name: 'plugins.eva.general.WideningDelay',
  signal: signalWideningDelay,
  getter: getWideningDelay,
  setter: setWideningDelay,
};
/** Widening delay */
export const WideningDelay: State.State<number> = WideningDelay_internal;

/** Signal for state [`HistoryPartitioning`](#historypartitioning)  */
export const signalHistoryPartitioning: Server.Signal = {
  name: 'plugins.eva.general.signalHistoryPartitioning',
};

const getHistoryPartitioning_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getHistoryPartitioning',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`HistoryPartitioning`](#historypartitioning)  */
export const getHistoryPartitioning: Server.GetRequest<null,number>= getHistoryPartitioning_internal;

const setHistoryPartitioning_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setHistoryPartitioning',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`HistoryPartitioning`](#historypartitioning)  */
export const setHistoryPartitioning: Server.SetRequest<number,null>= setHistoryPartitioning_internal;

const HistoryPartitioning_internal: State.State<number> = {
  name: 'plugins.eva.general.HistoryPartitioning',
  signal: signalHistoryPartitioning,
  getter: getHistoryPartitioning,
  setter: setHistoryPartitioning,
};
/** History partitioning */
export const HistoryPartitioning: State.State<number> = HistoryPartitioning_internal;

/** Signal for state [`ArrayPrecisionLevel`](#arrayprecisionlevel)  */
export const signalArrayPrecisionLevel: Server.Signal = {
  name: 'plugins.eva.general.signalArrayPrecisionLevel',
};

const getArrayPrecisionLevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getArrayPrecisionLevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`ArrayPrecisionLevel`](#arrayprecisionlevel)  */
export const getArrayPrecisionLevel: Server.GetRequest<null,number>= getArrayPrecisionLevel_internal;

const setArrayPrecisionLevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setArrayPrecisionLevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`ArrayPrecisionLevel`](#arrayprecisionlevel)  */
export const setArrayPrecisionLevel: Server.SetRequest<number,null>= setArrayPrecisionLevel_internal;

const ArrayPrecisionLevel_internal: State.State<number> = {
  name: 'plugins.eva.general.ArrayPrecisionLevel',
  signal: signalArrayPrecisionLevel,
  getter: getArrayPrecisionLevel,
  setter: setArrayPrecisionLevel,
};
/** Array precision level */
export const ArrayPrecisionLevel: State.State<number> = ArrayPrecisionLevel_internal;

/** Signal for state [`LinearLevel`](#linearlevel)  */
export const signalLinearLevel: Server.Signal = {
  name: 'plugins.eva.general.signalLinearLevel',
};

const getLinearLevel_internal: Server.GetRequest<null,number> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getLinearLevel',
  input: Json.jNull,
  output: Json.jNumber,
  fallback: 0,
  signals: [],
};
/** Getter for state [`LinearLevel`](#linearlevel)  */
export const getLinearLevel: Server.GetRequest<null,number>= getLinearLevel_internal;

const setLinearLevel_internal: Server.SetRequest<number,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setLinearLevel',
  input: Json.jNumber,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`LinearLevel`](#linearlevel)  */
export const setLinearLevel: Server.SetRequest<number,null>= setLinearLevel_internal;

const LinearLevel_internal: State.State<number> = {
  name: 'plugins.eva.general.LinearLevel',
  signal: signalLinearLevel,
  getter: getLinearLevel,
  setter: setLinearLevel,
};
/** Linear level */
export const LinearLevel: State.State<number> = LinearLevel_internal;

/** Signal for state [`EqualityCall`](#equalitycall)  */
export const signalEqualityCall: Server.Signal = {
  name: 'plugins.eva.general.signalEqualityCall',
};

const getEqualityCall_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getEqualityCall',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`EqualityCall`](#equalitycall)  */
export const getEqualityCall: Server.GetRequest<null,string>= getEqualityCall_internal;

const setEqualityCall_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setEqualityCall',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`EqualityCall`](#equalitycall)  */
export const setEqualityCall: Server.SetRequest<string,null>= setEqualityCall_internal;

const EqualityCall_internal: State.State<string> = {
  name: 'plugins.eva.general.EqualityCall',
  signal: signalEqualityCall,
  getter: getEqualityCall,
  setter: setEqualityCall,
};
/** Equality call */
export const EqualityCall: State.State<string> = EqualityCall_internal;

/** Signal for state [`OctagonCall`](#octagoncall)  */
export const signalOctagonCall: Server.Signal = {
  name: 'plugins.eva.general.signalOctagonCall',
};

const getOctagonCall_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getOctagonCall',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`OctagonCall`](#octagoncall)  */
export const getOctagonCall: Server.GetRequest<null,boolean>= getOctagonCall_internal;

const setOctagonCall_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setOctagonCall',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`OctagonCall`](#octagoncall)  */
export const setOctagonCall: Server.SetRequest<boolean,null>= setOctagonCall_internal;

const OctagonCall_internal: State.State<boolean> = {
  name: 'plugins.eva.general.OctagonCall',
  signal: signalOctagonCall,
  getter: getOctagonCall,
  setter: setOctagonCall,
};
/** Octagon call */
export const OctagonCall: State.State<boolean> = OctagonCall_internal;

/** Signal for state [`SplitReturn`](#splitreturn)  */
export const signalSplitReturn: Server.Signal = {
  name: 'plugins.eva.general.signalSplitReturn',
};

const getSplitReturn_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getSplitReturn',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`SplitReturn`](#splitreturn)  */
export const getSplitReturn: Server.GetRequest<null,string>= getSplitReturn_internal;

const setSplitReturn_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setSplitReturn',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`SplitReturn`](#splitreturn)  */
export const setSplitReturn: Server.SetRequest<string,null>= setSplitReturn_internal;

const SplitReturn_internal: State.State<string> = {
  name: 'plugins.eva.general.SplitReturn',
  signal: signalSplitReturn,
  getter: getSplitReturn,
  setter: setSplitReturn,
};
/** Split return value */
export const SplitReturn: State.State<string> = SplitReturn_internal;

/** Signal for state [`AllocReturnsNull`](#allocreturnsnull)  */
export const signalAllocReturnsNull: Server.Signal = {
  name: 'plugins.eva.general.signalAllocReturnsNull',
};

const getAllocReturnsNull_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getAllocReturnsNull',
  input: Json.jNull,
  output: Json.jBoolean,
  fallback: false,
  signals: [],
};
/** Getter for state [`AllocReturnsNull`](#allocreturnsnull)  */
export const getAllocReturnsNull: Server.GetRequest<null,boolean>= getAllocReturnsNull_internal;

const setAllocReturnsNull_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setAllocReturnsNull',
  input: Json.jBoolean,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`AllocReturnsNull`](#allocreturnsnull)  */
export const setAllocReturnsNull: Server.SetRequest<boolean,null>= setAllocReturnsNull_internal;

const AllocReturnsNull_internal: State.State<boolean> = {
  name: 'plugins.eva.general.AllocReturnsNull',
  signal: signalAllocReturnsNull,
  getter: getAllocReturnsNull,
  setter: setAllocReturnsNull,
};
/** AllocReturnsNull value */
export const AllocReturnsNull: State.State<boolean> = AllocReturnsNull_internal;

/** Signal for state [`WarnPointerComparison`](#warnpointercomparison)  */
export const signalWarnPointerComparison: Server.Signal = {
  name: 'plugins.eva.general.signalWarnPointerComparison',
};

const getWarnPointerComparison_internal: Server.GetRequest<null,string> = {
  kind: Server.RqKind.GET,
  name: 'plugins.eva.general.getWarnPointerComparison',
  input: Json.jNull,
  output: Json.jString,
  fallback: '',
  signals: [],
};
/** Getter for state [`WarnPointerComparison`](#warnpointercomparison)  */
export const getWarnPointerComparison: Server.GetRequest<null,string>= getWarnPointerComparison_internal;

const setWarnPointerComparison_internal: Server.SetRequest<string,null> = {
  kind: Server.RqKind.SET,
  name: 'plugins.eva.general.setWarnPointerComparison',
  input: Json.jString,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Setter for state [`WarnPointerComparison`](#warnpointercomparison)  */
export const setWarnPointerComparison: Server.SetRequest<string,null>= setWarnPointerComparison_internal;

const WarnPointerComparison_internal: State.State<string> = {
  name: 'plugins.eva.general.WarnPointerComparison',
  signal: signalWarnPointerComparison,
  getter: getWarnPointerComparison,
  setter: setWarnPointerComparison,
};
/** Warn pointer comparison value */
export const WarnPointerComparison: State.State<string> = WarnPointerComparison_internal;

/* ------------------------------------- */
