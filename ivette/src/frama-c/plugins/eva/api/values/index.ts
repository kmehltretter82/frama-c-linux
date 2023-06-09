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
   Eva Values
   @packageDocumentation
   @module frama-c/plugins/eva/api/values
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

/** Emitted when EVA results has changed */
export const changed: Server.Signal = {
  name: 'plugins.eva.values.changed',
};

export type callstack = Json.index<'#eva-callstack-id'>;

/** Decoder for `callstack` */
export const jCallstack: Json.Decoder<callstack> =
  Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id');

/** Natural order for `callstack` */
export const byCallstack: Compare.Order<callstack> = Compare.number;

/** Default value for `callstack` */
export const callstackDefault: callstack =
  Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id')(-1);

const getCallstacks_internal: Server.GetRequest<marker[],callstack[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getCallstacks',
  input:  Json.jArray(jMarker),
  output: Json.jArray(jCallstack),
  signals: [],
};
/** Callstacks for markers */
export const getCallstacks: Server.GetRequest<marker[],callstack[]>= getCallstacks_internal;

const getCallstackInfo_internal: Server.GetRequest<
  callstack,
  { callee: fct, caller?: fct, stmt?: marker, rank?: number }[]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getCallstackInfo',
  input:  jCallstack,
  output: Json.jArray(
            Json.jObject({
              callee: jFct,
              caller: Json.jOption(jFct),
              stmt: Json.jOption(jMarker),
              rank: Json.jOption(Json.jNumber),
            })),
  signals: [],
};
/** Callstack Description */
export const getCallstackInfo: Server.GetRequest<
  callstack,
  { callee: fct, caller?: fct, stmt?: marker, rank?: number }[]
  >= getCallstackInfo_internal;

const getStmtInfo_internal: Server.GetRequest<
  marker,
  { fct: fct, rank: number }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getStmtInfo',
  input:  jMarker,
  output: Json.jObject({ fct: jFct, rank: Json.jNumber,}),
  signals: [],
};
/** Stmt Information */
export const getStmtInfo: Server.GetRequest<
  marker,
  { fct: fct, rank: number }
  >= getStmtInfo_internal;

const getProbeInfo_internal: Server.GetRequest<
  marker,
  { evaluable: boolean, code?: string, stmt?: marker, effects: boolean,
    condition: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getProbeInfo',
  input:  jMarker,
  output: Json.jObject({
            evaluable: Json.jBoolean,
            code: Json.jOption(Json.jString),
            stmt: Json.jOption(jMarker),
            effects: Json.jBoolean,
            condition: Json.jBoolean,
          }),
  signals: [],
};
/** Probe informations */
export const getProbeInfo: Server.GetRequest<
  marker,
  { evaluable: boolean, code?: string, stmt?: marker, effects: boolean,
    condition: boolean }
  >= getProbeInfo_internal;

/** Evaluation of an expression or lvalue */
export interface evaluation {
  /** Textual representation of the value */
  value: string;
  /** Alarms raised by the evaluation */
  alarms: [ "True" | "False" | "Unknown", string ][];
  /** List of variables pointed by the value */
  pointedVars: [ string, marker ][];
}

/** Decoder for `evaluation` */
export const jEvaluation: Json.Decoder<evaluation> =
  Json.jObject({
    value: Json.jString,
    alarms: Json.jArray(
              Json.jPair(
                Json.jUnion<"True" | "False" | "Unknown">(
                  Json.jTag("True"),
                  Json.jTag("False"),
                  Json.jTag("Unknown"),
                ),
                Json.jString,
              )),
    pointedVars: Json.jArray(Json.jPair( Json.jString, jMarker,)),
  });

/** Natural order for `evaluation` */
export const byEvaluation: Compare.Order<evaluation> =
  Compare.byFields
    <{ value: string, alarms: [ "True" | "False" | "Unknown", string ][],
       pointedVars: [ string, marker ][] }>({
    value: Compare.string,
    alarms: Compare.array(Compare.pair(Compare.structural,Compare.string,)),
    pointedVars: Compare.array(Compare.pair(Compare.string,byMarker,)),
  });

/** Default value for `evaluation` */
export const evaluationDefault: evaluation =
  { value: '', alarms: [], pointedVars: [] };

const getValues_internal: Server.GetRequest<
  { target: marker, callstack?: callstack },
  { vBefore?: evaluation, vAfter?: evaluation, vThen?: evaluation,
    vElse?: evaluation }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getValues',
  input:  Json.jObject({
            target: jMarker,
            callstack: Json.jOption(jCallstack),
          }),
  output: Json.jObject({
            vBefore: Json.jOption(jEvaluation),
            vAfter: Json.jOption(jEvaluation),
            vThen: Json.jOption(jEvaluation),
            vElse: Json.jOption(jEvaluation),
          }),
  signals: [],
};
/** Abstract values for the given marker */
export const getValues: Server.GetRequest<
  { target: marker, callstack?: callstack },
  { vBefore?: evaluation, vAfter?: evaluation, vThen?: evaluation,
    vElse?: evaluation }
  >= getValues_internal;

/* ------------------------------------- */
