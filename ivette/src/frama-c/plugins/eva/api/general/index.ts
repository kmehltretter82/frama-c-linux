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
import { byMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { marker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { byTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tag } from 'frama-c/kernel/api/data';

/** State of the computation of Eva Analysis. */
export type computationStateType = "not_computed" | "computing" | "computed";

/** Decoder for `computationStateType` */
export const jComputationStateType: Json.Decoder<computationStateType> =
  Json.jUnion<"not_computed" | "computing" | "computed">(
    Json.jTag("not_computed"),
    Json.jTag("computing"),
    Json.jTag("computed"),
  );

/** Natural order for `computationStateType` */
export const byComputationStateType: Compare.Order<computationStateType> =
  Compare.structural;

/** Signal for state [`computationState`](#computationstate)  */
export const signalComputationState: Server.Signal = {
  name: 'plugins.eva.general.signalComputationState',
};

const getComputationState_internal: Server.GetRequest<
  null,
  computationStateType
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.getComputationState',
  input:  Json.jNull,
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

const getCallers_internal: Server.GetRequest<
  Json.key<'#fct'>,
  [ Json.key<'#fct'>, Json.key<'#stmt'> ][]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.getCallers',
  input:  Json.jKey<'#fct'>('#fct'),
  output: Json.jArray(
            Json.jPair(
              Json.jKey<'#fct'>('#fct'),
              Json.jKey<'#stmt'>('#stmt'),
            )),
  signals: [],
};
/** Get the list of call site of a function */
export const getCallers: Server.GetRequest<
  Json.key<'#fct'>,
  [ Json.key<'#fct'>, Json.key<'#stmt'> ][]
  >= getCallers_internal;

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
  name:   'plugins.eva.general.reloadFunctions',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`functions`](#functions)  */
export const reloadFunctions: Server.GetRequest<null,null>= reloadFunctions_internal;

const fetchFunctions_internal: Server.GetRequest<
  number,
  { pending: number, updated: functionsData[],
    removed: Json.key<'#functions'>[], reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.fetchFunctions',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jNumber,
            updated: Json.jArray(jFunctionsData),
            removed: Json.jArray(Json.jKey<'#functions'>('#functions')),
            reload: Json.jBoolean,
          }),
  signals: [],
};
/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest<
  number,
  { pending: number, updated: functionsData[],
    removed: Json.key<'#functions'>[], reload: boolean }
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

/** Unreachable and non terminating statements. */
export interface deadCode {
  /** List of unreachable statements. */
  unreachable: marker[];
  /** List of reachable but non terminating statements. */
  nonTerminating: marker[];
}

/** Decoder for `deadCode` */
export const jDeadCode: Json.Decoder<deadCode> =
  Json.jObject({
    unreachable: Json.jArray(jMarker),
    nonTerminating: Json.jArray(jMarker),
  });

/** Natural order for `deadCode` */
export const byDeadCode: Compare.Order<deadCode> =
  Compare.byFields
    <{ unreachable: marker[], nonTerminating: marker[] }>({
    unreachable: Compare.array(byMarker),
    nonTerminating: Compare.array(byMarker),
  });

const getDeadCode_internal: Server.GetRequest<Json.key<'#fct'>,deadCode> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.getDeadCode',
  input:  Json.jKey<'#fct'>('#fct'),
  output: jDeadCode,
  signals: [],
};
/** Get the lists of unreachable and of non terminating statements in a function */
export const getDeadCode: Server.GetRequest<Json.key<'#fct'>,deadCode>= getDeadCode_internal;

const taintedLvalues_internal: Server.GetRequest<
  Json.key<'#fundec'>,
  { lval: Json.key<'#lval'>,
    before:
        { data: "direct" | "indirect" | "untainted",
          indirect: "direct" | "indirect" | "untainted" },
    after:
        { data: "direct" | "indirect" | "untainted",
          indirect: "direct" | "indirect" | "untainted" } }[]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.taintedLvalues',
  input:  Json.jKey<'#fundec'>('#fundec'),
  output: Json.jArray(
            Json.jObject({
              lval: Json.jKey<'#lval'>('#lval'),
              before: Json.jObject({
                        data: Json.jUnion<"direct" | "indirect" | "untainted">(
                                Json.jTag("direct"),
                                Json.jTag("indirect"),
                                Json.jTag("untainted"),
                              ),
                        indirect: Json.jUnion<"direct" | "indirect" |
                                              "untainted">(
                                    Json.jTag("direct"),
                                    Json.jTag("indirect"),
                                    Json.jTag("untainted"),
                                  ),
                      }),
              after: Json.jObject({
                       data: Json.jUnion<"direct" | "indirect" | "untainted">(
                               Json.jTag("direct"),
                               Json.jTag("indirect"),
                               Json.jTag("untainted"),
                             ),
                       indirect: Json.jUnion<"direct" | "indirect" |
                                             "untainted">(
                                   Json.jTag("direct"),
                                   Json.jTag("indirect"),
                                   Json.jTag("untainted"),
                                 ),
                     }),
            })),
  signals: [],
};
/** Get the tainted lvalues of a given function */
export const taintedLvalues: Server.GetRequest<
  Json.key<'#fundec'>,
  { lval: Json.key<'#lval'>,
    before:
        { data: "direct" | "indirect" | "untainted",
          indirect: "direct" | "indirect" | "untainted" },
    after:
        { data: "direct" | "indirect" | "untainted",
          indirect: "direct" | "indirect" | "untainted" } }[]
  >= taintedLvalues_internal;

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

const taintStatusTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.taintStatusTags',
  input:  Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const taintStatusTags: Server.GetRequest<null,tag[]>= taintStatusTags_internal;

/** Data for array rows [`properties`](#properties)  */
export interface propertiesData {
  /** Entry identifier. */
  key: Json.key<'#property'>;
  /** Is the property invalid in some context of the analysis? */
  priority: boolean;
  /** Is the property tainted according to the Eva taint domain? */
  taint: taintStatus;
}

/** Decoder for `propertiesData` */
export const jPropertiesData: Json.Decoder<propertiesData> =
  Json.jObject({
    key: Json.jKey<'#property'>('#property'),
    priority: Json.jBoolean,
    taint: jTaintStatus,
  });

/** Natural order for `propertiesData` */
export const byPropertiesData: Compare.Order<propertiesData> =
  Compare.byFields
    <{ key: Json.key<'#property'>, priority: boolean, taint: taintStatus }>({
    key: Compare.string,
    priority: Compare.boolean,
    taint: byTaintStatus,
  });

/** Signal for array [`properties`](#properties)  */
export const signalProperties: Server.Signal = {
  name: 'plugins.eva.general.signalProperties',
};

const reloadProperties_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.reloadProperties',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`properties`](#properties)  */
export const reloadProperties: Server.GetRequest<null,null>= reloadProperties_internal;

const fetchProperties_internal: Server.GetRequest<
  number,
  { pending: number, updated: propertiesData[],
    removed: Json.key<'#property'>[], reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.fetchProperties',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jNumber,
            updated: Json.jArray(jPropertiesData),
            removed: Json.jArray(Json.jKey<'#property'>('#property')),
            reload: Json.jBoolean,
          }),
  signals: [],
};
/** Data fetcher for array [`properties`](#properties)  */
export const fetchProperties: Server.GetRequest<
  number,
  { pending: number, updated: propertiesData[],
    removed: Json.key<'#property'>[], reload: boolean }
  >= fetchProperties_internal;

const properties_internal: State.Array<Json.key<'#property'>,propertiesData> = {
  name: 'plugins.eva.general.properties',
  getkey: ((d:propertiesData) => d.key),
  signal: signalProperties,
  fetch: fetchProperties,
  reload: reloadProperties,
  order: byPropertiesData,
};
/** Status of Registered Properties */
export const properties: State.Array<Json.key<'#property'>,propertiesData> = properties_internal;

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

const alarmCategoryTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.alarmCategoryTags',
  input:  Json.jNull,
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

/** Signal for state [`programStats`](#programstats)  */
export const signalProgramStats: Server.Signal = {
  name: 'plugins.eva.general.signalProgramStats',
};

const getProgramStats_internal: Server.GetRequest<null,programStatsType> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.getProgramStats',
  input:  Json.jNull,
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
  key: Json.key<'#fundec'>;
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
    key: Json.jKey<'#fundec'>('#fundec'),
    coverage: Json.jObject({ reachable: Json.jNumber, dead: Json.jNumber,}),
    alarmCount: Json.jArray(jAlarmEntry),
    alarmStatuses: jStatusesEntry,
  });

/** Natural order for `functionStatsData` */
export const byFunctionStatsData: Compare.Order<functionStatsData> =
  Compare.byFields
    <{ key: Json.key<'#fundec'>,
       coverage: { reachable: number, dead: number },
       alarmCount: alarmEntry[], alarmStatuses: statusesEntry }>({
    key: Compare.string,
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
  name:   'plugins.eva.general.reloadFunctionStats',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`functionStats`](#functionstats)  */
export const reloadFunctionStats: Server.GetRequest<null,null>= reloadFunctionStats_internal;

const fetchFunctionStats_internal: Server.GetRequest<
  number,
  { pending: number, updated: functionStatsData[],
    removed: Json.key<'#fundec'>[], reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.fetchFunctionStats',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jNumber,
            updated: Json.jArray(jFunctionStatsData),
            removed: Json.jArray(Json.jKey<'#fundec'>('#fundec')),
            reload: Json.jBoolean,
          }),
  signals: [],
};
/** Data fetcher for array [`functionStats`](#functionstats)  */
export const fetchFunctionStats: Server.GetRequest<
  number,
  { pending: number, updated: functionStatsData[],
    removed: Json.key<'#fundec'>[], reload: boolean }
  >= fetchFunctionStats_internal;

const functionStats_internal: State.Array<
  Json.key<'#fundec'>,
  functionStatsData
  > = {
  name: 'plugins.eva.general.functionStats',
  getkey: ((d:functionStatsData) => d.key),
  signal: signalFunctionStats,
  fetch: fetchFunctionStats,
  reload: reloadFunctionStats,
  order: byFunctionStatsData,
};
/** Statistics about the last Eva analysis for each function */
export const functionStats: State.Array<
  Json.key<'#fundec'>,
  functionStatsData
  > = functionStats_internal;

const getStates_internal: Server.GetRequest<
  [ marker, boolean ],
  [ string, string, string ][]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.getStates',
  input:  Json.jPair( jMarker, Json.jBoolean,),
  output: Json.jArray(
            Json.jTriple( Json.jString, Json.jString, Json.jString,)),
  signals: [],
};
/** Get the domain states about the given marker */
export const getStates: Server.GetRequest<
  [ marker, boolean ],
  [ string, string, string ][]
  >= getStates_internal;

/* ------------------------------------- */
