/* --- Generated Frama-C Server API --- */

/**
   Eva General Services
   @packageDocumentation
   @module frama-c/api/plugins/eva/general
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

const getCallers_internal: Server.GetRequest<
  Json.key<'#fct'>,
  [ Json.key<'#fct'>, Json.key<'#stmt'> ][]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.getCallers',
  input:  Json.jKey<'#fct'>('#fct'),
  output: Json.jList(
            Json.jTry(
              Json.jPair(
                Json.jFail(Json.jKey<'#fct'>('#fct'),'#fct expected'),
                Json.jFail(Json.jKey<'#stmt'>('#stmt'),'#stmt expected'),
              ))),
};
/** Get the list of call site of a function */
export const getCallers: Server.GetRequest<
  Json.key<'#fct'>,
  [ Json.key<'#fct'>, Json.key<'#stmt'> ][]
  >= getCallers_internal;

/** Unreachable and non terminating statements. */
export interface deadCode {
  /** List of unreachable statements. */
  unreachable: marker[];
  /** List of reachable but non terminating statements. */
  nonTerminating: marker[];
}

/** Loose decoder for `deadCode` */
export const jDeadCode: Json.Loose<deadCode> =
  Json.jObject({
    unreachable: Json.jList(jMarker),
    nonTerminating: Json.jList(jMarker),
  });

/** Safe decoder for `deadCode` */
export const jDeadCodeSafe: Json.Safe<deadCode> =
  Json.jFail(jDeadCode,'DeadCode expected');

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
};
/** Get the lists of unreachable and of non terminating statements in a function */
export const getDeadCode: Server.GetRequest<Json.key<'#fct'>,deadCode>= getDeadCode_internal;

/* ------------------------------------- */
