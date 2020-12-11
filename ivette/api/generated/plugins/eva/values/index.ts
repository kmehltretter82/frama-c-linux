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

const getCallstacks_internal: Server.GetRequest<
  Json.key<'#stmt'>,
  Json.index<'#eva-callstack-id'>[]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getCallstacks',
  input:  Json.jKey<'#stmt'>('#stmt'),
  output: Json.jList(Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id')),
};
/** Callstacks for markers */
export const getCallstacks: Server.GetRequest<
  Json.key<'#stmt'>,
  Json.index<'#eva-callstack-id'>[]
  >= getCallstacks_internal;

const getCallstackInfo_internal: Server.GetRequest<
  Json.index<'#eva-callstack-id'>,
  { calls:
        { fct: Json.key<'#fct'>, stmt?: Json.key<'#stmt'>, rank: number }[],
    descr: string }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getCallstackInfo',
  input:  Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id'),
  output: Json.jObject({
            calls: Json.jList(
                     Json.jObject({
                       fct: Json.jFail(Json.jKey<'#fct'>('#fct'),
                              '#fct expected'),
                       stmt: Json.jKey<'#stmt'>('#stmt'),
                       rank: Json.jFail(Json.jNumber,'Number expected'),
                     })),
            descr: Json.jFail(Json.jString,'String expected'),
          }),
};
/** Callstack Description */
export const getCallstackInfo: Server.GetRequest<
  Json.index<'#eva-callstack-id'>,
  { calls:
        { fct: Json.key<'#fct'>, stmt?: Json.key<'#stmt'>, rank: number }[],
    descr: string }
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
  { rank: number, code?: string, stmt?: Json.key<'#stmt'> }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getProbeInfo',
  input:  jMarker,
  output: Json.jObject({
            rank: Json.jFail(Json.jNumber,'Number expected'),
            code: Json.jString,
            stmt: Json.jKey<'#stmt'>('#stmt'),
          }),
};
/** Probe informations */
export const getProbeInfo: Server.GetRequest<
  marker,
  { rank: number, code?: string, stmt?: Json.key<'#stmt'> }
  >= getProbeInfo_internal;

const getValues_internal: Server.GetRequest<
  { callstacks?: Json.index<'#eva-callstack-id'>, target: marker },
  { v_else?: string, v_then?: string, v_after?: string, values?: string,
    alarms: [ "True" | "False" | "Unknown", string ][] }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getValues',
  input:  Json.jObject({
            callstacks: Json.jIndex<'#eva-callstack-id'>('#eva-callstack-id'),
            target: jMarkerSafe,
          }),
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
  { callstacks?: Json.index<'#eva-callstack-id'>, target: marker },
  { v_else?: string, v_then?: string, v_after?: string, values?: string,
    alarms: [ "True" | "False" | "Unknown", string ][] }
  >= getValues_internal;

/* ------------------------------------- */
