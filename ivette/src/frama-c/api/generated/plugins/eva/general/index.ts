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
//@ts-ignore
import { byTag } from 'frama-c/api/kernel/data';
//@ts-ignore
import { jTag } from 'frama-c/api/kernel/data';
//@ts-ignore
import { jTagSafe } from 'frama-c/api/kernel/data';
//@ts-ignore
import { tag } from 'frama-c/api/kernel/data';

const isComputed_internal: Server.GetRequest<null,boolean> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.isComputed',
  input:  Json.jNull,
  output: Json.jBoolean,
};
/** True if the Eva analysis has been done */
export const isComputed: Server.GetRequest<null,boolean>= isComputed_internal;

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

/** TODO */
export enum taintStatus {
  /** The Eva taint analysis has not been computed */
  not_computed = 'not_computed',
  /** Error: the memory zone on which this property depends could not be computed */
  error = 'error',
  /** No taint for this kind of property */
  not_applicable = 'not_applicable',
  /** Tainted property: this property is related to a memory zone that can be affected by an attacker, according to the Eva taint domain. */
  tainted = 'tainted',
  /** Untainted property: this property is safe, according to the Eva taint domain. */
  not_tainted = 'not_tainted',
}

/** Loose decoder for `taintStatus` */
export const jTaintStatus: Json.Loose<taintStatus> = Json.jEnum(taintStatus);

/** Safe decoder for `taintStatus` */
export const jTaintStatusSafe: Json.Safe<taintStatus> =
  Json.jFail(Json.jEnum(taintStatus),
    'plugins.eva.general.taintStatus expected');

/** Natural order for `taintStatus` */
export const byTaintStatus: Compare.Order<taintStatus> =
  Compare.byEnum(taintStatus);

const taintStatusTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.general.taintStatusTags',
  input:  Json.jNull,
  output: Json.jList(jTag),
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

/** Loose decoder for `propertiesData` */
export const jPropertiesData: Json.Loose<propertiesData> =
  Json.jObject({
    key: Json.jFail(Json.jKey<'#property'>('#property'),'#property expected'),
    priority: Json.jFail(Json.jBoolean,'Boolean expected'),
    taint: jTaintStatusSafe,
  });

/** Safe decoder for `propertiesData` */
export const jPropertiesDataSafe: Json.Safe<propertiesData> =
  Json.jFail(jPropertiesData,'PropertiesData expected');

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
            pending: Json.jFail(Json.jNumber,'Number expected'),
            updated: Json.jList(jPropertiesData),
            removed: Json.jList(Json.jKey<'#property'>('#property')),
            reload: Json.jFail(Json.jBoolean,'Boolean expected'),
          }),
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

/* ------------------------------------- */
