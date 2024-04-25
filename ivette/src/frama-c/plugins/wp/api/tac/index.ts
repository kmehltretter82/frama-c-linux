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

//@ts-ignore
import { byNode } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { byTactic } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { jNode } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { jTactic } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { node } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { nodeDefault } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { tactic } from 'frama-c/plugins/wp/api/tip';
//@ts-ignore
import { tacticDefault } from 'frama-c/plugins/wp/api/tip';

/** Parameter kind */
export type kind =
  "checkbox" | "spinner" | "selector" | "browser" | "editor";

/** Decoder for `kind` */
export const jKind: Json.Decoder<kind> =
  Json.jUnion<"checkbox" | "spinner" | "selector" | "browser" | "editor">(
    Json.jTag("checkbox"),
    Json.jTag("spinner"),
    Json.jTag("selector"),
    Json.jTag("browser"),
    Json.jTag("editor"),
  );

/** Natural order for `kind` */
export const byKind: Compare.Order<kind> = Compare.structural;

/** Default value for `kind` */
export const kindDefault: kind = "checkbox";

/** Tactical status */
export type status = "NotApplicable" | "NotConfigured" | "Applicable";

/** Decoder for `status` */
export const jStatus: Json.Decoder<status> =
  Json.jUnion<"NotApplicable" | "NotConfigured" | "Applicable">(
    Json.jTag("NotApplicable"),
    Json.jTag("NotConfigured"),
    Json.jTag("Applicable"),
  );

/** Natural order for `status` */
export const byStatus: Compare.Order<status> = Compare.structural;

/** Default value for `status` */
export const statusDefault: status = "NotApplicable";

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

/** Default value for `value` */
export const valueDefault: value =
  { id: Json.jKey<'#value'>('#value')(''), label: '', title: '' };

/** Parameter configuration */
export interface parameter {
  /** Parameter identifier */
  id: Json.key<'#param'>;
  /** Parameter kind */
  kind: kind;
  /** Short name */
  label: string;
  /** Description */
  title: string;
  /** Enabled parameter */
  enabled: boolean;
  /** Value (with respect to kind) */
  value: Json.json;
  /** Minimum range value (spinner only) */
  vmin?: number;
  /** Maximum range value (spinner only) */
  vmax?: number;
  /** Range step (spinner only) */
  vstep?: number;
  /** List of options (selector only) */
  vlist?: value[];
}

/** Decoder for `parameter` */
export const jParameter: Json.Decoder<parameter> =
  Json.jObject({
    id: Json.jKey<'#param'>('#param'),
    kind: jKind,
    label: Json.jString,
    title: Json.jString,
    enabled: Json.jBoolean,
    value: Json.jAny,
    vmin: Json.jOption(Json.jNumber),
    vmax: Json.jOption(Json.jNumber),
    vstep: Json.jOption(Json.jNumber),
    vlist: Json.jOption(Json.jArray(jValue)),
  });

/** Natural order for `parameter` */
export const byParameter: Compare.Order<parameter> =
  Compare.byFields
    <{ id: Json.key<'#param'>, kind: kind, label: string, title: string,
       enabled: boolean, value: Json.json, vmin?: number, vmax?: number,
       vstep?: number, vlist?: value[] }>({
    id: Compare.string,
    kind: byKind,
    label: Compare.string,
    title: Compare.string,
    enabled: Compare.boolean,
    value: Compare.structural,
    vmin: Compare.defined(Compare.number),
    vmax: Compare.defined(Compare.number),
    vstep: Compare.defined(Compare.number),
    vlist: Compare.defined(Compare.array(byValue)),
  });

/** Default value for `parameter` */
export const parameterDefault: parameter =
  { id: Json.jKey<'#param'>('#param')(''), kind: kindDefault, label: '',
    title: '', enabled: false, value: null, vmin: undefined, vmax: undefined,
    vstep: undefined, vlist: undefined };

/** Data for array rows [`tactical`](#tactical)  */
export interface tacticalData {
  /** Entry identifier. */
  id: tactic;
  /** Tactic name */
  label: string;
  /** Tactic description */
  title: string;
  /** Tactic error */
  error?: string;
  /** Tactic status */
  status: status;
  /** Configuration parameters */
  params: parameter[];
}

/** Decoder for `tacticalData` */
export const jTacticalData: Json.Decoder<tacticalData> =
  Json.jObject({
    id: jTactic,
    label: Json.jString,
    title: Json.jString,
    error: Json.jOption(Json.jString),
    status: jStatus,
    params: Json.jArray(jParameter),
  });

/** Natural order for `tacticalData` */
export const byTacticalData: Compare.Order<tacticalData> =
  Compare.byFields
    <{ id: tactic, label: string, title: string, error?: string,
       status: status, params: parameter[] }>({
    id: byTactic,
    label: Compare.string,
    title: Compare.string,
    error: Compare.defined(Compare.string),
    status: byStatus,
    params: Compare.array(byParameter),
  });

/** Signal for array [`tactical`](#tactical)  */
export const signalTactical: Server.Signal = {
  name: 'plugins.wp.tac.signalTactical',
};

const reloadTactical_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tac.reloadTactical',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`tactical`](#tactical)  */
export const reloadTactical: Server.GetRequest<null,null>= reloadTactical_internal;

const fetchTactical_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: tactic[], updated: tacticalData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'plugins.wp.tac.fetchTactical',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jTactic),
            updated: Json.jArray(jTacticalData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`tactical`](#tactical)  */
export const fetchTactical: Server.GetRequest<
  number,
  { reload: boolean, removed: tactic[], updated: tacticalData[],
    pending: number }
  >= fetchTactical_internal;

const tactical_internal: State.Array<tactic,tacticalData> = {
  name: 'plugins.wp.tac.tactical',
  getkey: ((d:tacticalData) => d.id),
  signal: signalTactical,
  fetch: fetchTactical,
  reload: reloadTactical,
  order: byTacticalData,
};
/** Tactical Configurations */
export const tactical: State.Array<tactic,tacticalData> = tactical_internal;

/** Default value for `tacticalData` */
export const tacticalDataDefault: tacticalData =
  { id: tacticDefault, label: '', title: '', error: undefined,
    status: statusDefault, params: [] };

const configureTactics_internal: Server.ExecRequest<node,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.wp.tac.configureTactics',
  input: jNode,
  output: Json.jNull,
  signals: [ { name: 'plugins.wp.tip.printStatus' } ],
};
/** Configure all tactics */
export const configureTactics: Server.ExecRequest<node,null>= configureTactics_internal;

const setParameter_internal: Server.ExecRequest<
  { node: node, tactic: tactic, param: Json.key<'#param'>, value: Json.json },
  null
  > = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.wp.tac.setParameter',
  input: Json.jObject({
           node: jNode,
           tactic: jTactic,
           param: Json.jKey<'#param'>('#param'),
           value: Json.jAny,
         }),
  output: Json.jNull,
  signals: [],
};
/** Configure tactical parameter */
export const setParameter: Server.ExecRequest<
  { node: node, tactic: tactic, param: Json.key<'#param'>, value: Json.json },
  null
  >= setParameter_internal;

const applyTactic_internal: Server.ExecRequest<tactic,node[]> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.wp.tac.applyTactic',
  input: jTactic,
  output: Json.jArray(jNode),
  signals: [],
};
/** Applies the (configured) tactic */
export const applyTactic: Server.ExecRequest<tactic,node[]>= applyTactic_internal;

const applyTacticAndProve_internal: Server.ExecRequest<tactic,node[]> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.wp.tac.applyTacticAndProve',
  input: jTactic,
  output: Json.jArray(jNode),
  signals: [],
};
/** Applies tactic and run provers on children */
export const applyTacticAndProve: Server.ExecRequest<tactic,node[]>= applyTacticAndProve_internal;

/* ------------------------------------- */
