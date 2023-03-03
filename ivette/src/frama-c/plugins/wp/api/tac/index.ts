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
   WP Tactics
   @packageDocumentation
   @module frama-c/plugins/wp/api/tac
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';


/** TIP Tactic Information */
export type tactic =
  { id: Json.key<'#tactic'>, label: string, title: string };

/** Decoder for `tactic` */
export const jTactic: Json.Decoder<tactic> =
  Json.jObject({
    id: Json.jKey<'#tactic'>('#tactic'),
    label: Json.jString,
    title: Json.jString,
  });

/** Natural order for `tactic` */
export const byTactic: Compare.Order<tactic> =
  Compare.byFields
    <{ id: Json.key<'#tactic'>, label: string, title: string }>({
    id: Compare.string,
    label: Compare.string,
    title: Compare.string,
  });

const getTactics_internal: Server.GetRequest<null,tactic[]> = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.tac.getTactics',
  input:  Json.jNull,
  output: Json.jArray(jTactic),
  signals: [],
};
/** List of registered tactics */
export const getTactics: Server.GetRequest<null,tactic[]>= getTactics_internal;

/** Parameter option value */
export type value = { id: Json.key<'#value'>, label: string, title: string };

/** Decoder for `value` */
export const jValue: Json.Decoder<value> =
  Json.jObject({
    id: Json.jKey<'#value'>('#value'),
    label: Json.jString,
    title: Json.jString,
  });

/** Natural order for `value` */
export const byValue: Compare.Order<value> =
  Compare.byFields
    <{ id: Json.key<'#value'>, label: string, title: string }>({
    id: Compare.string,
    label: Compare.string,
    title: Compare.string,
  });

/** Parameter kind */
export type kind =
  "checkbox" | "spinner" | "selector" | "editor" | "browser";

/** Decoder for `kind` */
export const jKind: Json.Decoder<kind> =
  Json.jUnion<"checkbox" | "spinner" | "selector" | "editor" | "browser">(
    Json.jTag("checkbox"),
    Json.jTag("spinner"),
    Json.jTag("selector"),
    Json.jTag("editor"),
    Json.jTag("browser"),
  );

/** Natural order for `kind` */
export const byKind: Compare.Order<kind> = Compare.structural;

/** TIP Tactic Information */
export type parameter =
  { kind: kind, id: Json.key<'#param'>, label: string, title: string,
    value: Json.json, enabled: boolean, vmin?: number, vmax?: number,
    vstep?: number, vlist?: value[] };

/** Decoder for `parameter` */
export const jParameter: Json.Decoder<parameter> =
  Json.jObject({
    kind: jKind,
    id: Json.jKey<'#param'>('#param'),
    label: Json.jString,
    title: Json.jString,
    value: Json.jAny,
    enabled: Json.jBoolean,
    vmin: Json.jOption(Json.jNumber),
    vmax: Json.jOption(Json.jNumber),
    vstep: Json.jOption(Json.jNumber),
    vlist: Json.jOption(Json.jArray(jValue)),
  });

/** Natural order for `parameter` */
export const byParameter: Compare.Order<parameter> =
  Compare.byFields
    <{ kind: kind, id: Json.key<'#param'>, label: string, title: string,
       value: Json.json, enabled: boolean, vmin?: number, vmax?: number,
       vstep?: number, vlist?: value[] }>({
    kind: byKind,
    id: Compare.string,
    label: Compare.string,
    title: Compare.string,
    value: Compare.structural,
    enabled: Compare.boolean,
    vmin: Compare.defined(Compare.number),
    vmax: Compare.defined(Compare.number),
    vstep: Compare.defined(Compare.number),
    vlist: Compare.defined(Compare.array(byValue)),
  });

/** Tactical configuration modified */
export const configured: Server.Signal = {
  name: 'plugins.wp.tac.configured',
};

const getParameters_internal: Server.GetRequest<
  Json.key<'#tactic'>,
  parameter[]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.wp.tac.getParameters',
  input:  Json.jKey<'#tactic'>('#tactic'),
  output: Json.jArray(jParameter),
  signals: [ { name: 'plugins.wp.tac.configured' } ],
};
/** Return tactical current parameters */
export const getParameters: Server.GetRequest<
  Json.key<'#tactic'>,
  parameter[]
  >= getParameters_internal;

/* ------------------------------------- */
