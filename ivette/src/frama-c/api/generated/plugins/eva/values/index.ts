/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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
   @module frama-c/api/plugins/eva/values
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
import { byMarker } from 'frama-c/api/kernel/ast';
//@ts-ignore
import { jMarker } from 'frama-c/api/kernel/ast';
//@ts-ignore
import { jMarkerSafe } from 'frama-c/api/kernel/ast';
//@ts-ignore
import { marker } from 'frama-c/api/kernel/ast';

/** Emitted when EVA results has changed */
export const changed: Server.Signal = {
  name: 'plugins.eva.values.changed',
};

export type callstack = Json.index<'#eva-callstack-id'>;

/** Loose decoder for `callstack` */
export const jCallstack: Json.Loose<callstack> =
  Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id');

/** Safe decoder for `callstack` */
export const jCallstackSafe: Json.Safe<callstack> =
  Json.jFail(Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id'),
    '#eva-callstack-id expected');

/** Natural order for `callstack` */
export const byCallstack: Compare.Order<callstack> = Compare.number;

const getCallstacks_internal: Server.GetRequest<marker[],callstack[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getCallstacks',
  input:  Json.jList(jMarker),
  output: Json.jList(jCallstack),
};
/** Callstacks for markers */
export const getCallstacks: Server.GetRequest<marker[],callstack[]>= getCallstacks_internal;

const getCallstackInfo_internal: Server.GetRequest<
  callstack,
  { callee: Json.key<'#fct'>, caller?: Json.key<'#fct'>,
    stmt?: Json.key<'#stmt'>, rank?: number }[]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getCallstackInfo',
  input:  jCallstack,
  output: Json.jList(
            Json.jObject({
              callee: Json.jFail(Json.jKey<'#fct'>('#fct'),'#fct expected'),
              caller: Json.jKey<'#fct'>('#fct'),
              stmt: Json.jKey<'#stmt'>('#stmt'),
              rank: Json.jNumber,
            })),
};
/** Callstack Description */
export const getCallstackInfo: Server.GetRequest<
  callstack,
  { callee: Json.key<'#fct'>, caller?: Json.key<'#fct'>,
    stmt?: Json.key<'#stmt'>, rank?: number }[]
  >= getCallstackInfo_internal;

const getStmtInfo_internal: Server.GetRequest<
  Json.key<'#stmt'>,
  { rank: number, fct: Json.key<'#fct'> }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getStmtInfo',
  input:  Json.jKey<'#stmt'>('#stmt'),
  output: Json.jObject({
            rank: Json.jFail(Json.jNumber,'Number expected'),
            fct: Json.jFail(Json.jKey<'#fct'>('#fct'),'#fct expected'),
          }),
};
/** Stmt Information */
export const getStmtInfo: Server.GetRequest<
  Json.key<'#stmt'>,
  { rank: number, fct: Json.key<'#fct'> }
  >= getStmtInfo_internal;

const getProbeInfo_internal: Server.GetRequest<
  marker,
  { condition: boolean, effects: boolean, rank: number,
    stmt?: Json.key<'#stmt'>, code?: string }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getProbeInfo',
  input:  jMarker,
  output: Json.jObject({
            condition: Json.jFail(Json.jBoolean,'Boolean expected'),
            effects: Json.jFail(Json.jBoolean,'Boolean expected'),
            rank: Json.jFail(Json.jNumber,'Number expected'),
            stmt: Json.jKey<'#stmt'>('#stmt'),
            code: Json.jString,
          }),
};
/** Probe informations */
export const getProbeInfo: Server.GetRequest<
  marker,
  { condition: boolean, effects: boolean, rank: number,
    stmt?: Json.key<'#stmt'>, code?: string }
  >= getProbeInfo_internal;

const getValues_internal: Server.GetRequest<
  { callstack?: callstack, target: marker },
  { v_else?: string, v_then?: string, v_after?: string, values?: string,
    alarms: [ "True" | "False" | "Unknown", string ][] }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getValues',
  input:  Json.jObject({ callstack: jCallstack, target: jMarkerSafe,}),
  output: Json.jObject({
            v_else: Json.jString,
            v_then: Json.jString,
            v_after: Json.jString,
            values: Json.jString,
            alarms: Json.jList(
                      Json.jTry(
                        Json.jPair(
                          Json.jFail(
                            Json.jUnion<"True" | "False" | "Unknown">(
                              Json.jTag("True"),
                              Json.jTag("False"),
                              Json.jTag("Unknown"),
                            ),'Union expected'),
                          Json.jFail(Json.jString,'String expected'),
                        ))),
          }),
};
/** Abstract values for the given marker */
export const getValues: Server.GetRequest<
  { callstack?: callstack, target: marker },
  { v_else?: string, v_then?: string, v_after?: string, values?: string,
    alarms: [ "True" | "False" | "Unknown", string ][] }
  >= getValues_internal;

/* ------------------------------------- */
