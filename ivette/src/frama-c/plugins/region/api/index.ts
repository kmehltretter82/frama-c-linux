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
   Region Analysis
   @packageDocumentation
   @module frama-c/plugins/region/api
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

export type node = Json.index<'#node'>;

/** Decoder for `node` */
export const jNode: Json.Decoder<node> = Json.jIndex<'#node'>('#node');

/** Natural order for `node` */
export const byNode: Compare.Order<node> = Compare.number;

/** Default value for `node` */
export const nodeDefault: node = Json.jIndex<'#node'>('#node')(-1);

export type range =
  { label: string, offset: number, length: number, cells: number, data: node
    };

/** Decoder for `range` */
export const jRange: Json.Decoder<range> =
  Json.jObject({
    label: Json.jString,
    offset: Json.jNumber,
    length: Json.jNumber,
    cells: Json.jNumber,
    data: jNode,
  });

/** Natural order for `range` */
export const byRange: Compare.Order<range> =
  Compare.byFields
    <{ label: string, offset: number, length: number, cells: number,
       data: node }>({
    label: Compare.string,
    offset: Compare.number,
    length: Compare.number,
    cells: Compare.number,
    data: byNode,
  });

/** Default value for `range` */
export const rangeDefault: range =
  { label: '', offset: 0, length: 0, cells: 0, data: nodeDefault };

export type region =
  { node: node, roots: string[], labels: string[], parents: node[],
    sizeof: number, ranges: range[], pointed?: node, reads: boolean,
    writes: boolean, bytes: boolean, label: string, title: string };

/** Decoder for `region` */
export const jRegion: Json.Decoder<region> =
  Json.jObject({
    node: jNode,
    roots: Json.jArray(Json.jString),
    labels: Json.jArray(Json.jString),
    parents: Json.jArray(jNode),
    sizeof: Json.jNumber,
    ranges: Json.jArray(jRange),
    pointed: Json.jOption(jNode),
    reads: Json.jBoolean,
    writes: Json.jBoolean,
    bytes: Json.jBoolean,
    label: Json.jString,
    title: Json.jString,
  });

/** Natural order for `region` */
export const byRegion: Compare.Order<region> =
  Compare.byFields
    <{ node: node, roots: string[], labels: string[], parents: node[],
       sizeof: number, ranges: range[], pointed?: node, reads: boolean,
       writes: boolean, bytes: boolean, label: string, title: string }>({
    node: byNode,
    roots: Compare.array(Compare.alpha),
    labels: Compare.array(Compare.alpha),
    parents: Compare.array(byNode),
    sizeof: Compare.number,
    ranges: Compare.array(byRange),
    pointed: Compare.defined(byNode),
    reads: Compare.boolean,
    writes: Compare.boolean,
    bytes: Compare.boolean,
    label: Compare.string,
    title: Compare.string,
  });

/** Default value for `region` */
export const regionDefault: region =
  { node: nodeDefault, roots: [], labels: [], parents: [], sizeof: 0,
    ranges: [], pointed: undefined, reads: false, writes: false,
    bytes: false, label: '', title: '' };

/** Region Analysis Updated */
export const updated: Server.Signal = {
  name: 'plugins.region.updated',
};

const compute_internal: Server.ExecRequest<decl,null> = {
  kind: Server.RqKind.EXEC,
  name: 'plugins.region.compute',
  input: jDecl,
  output: Json.jNull,
  fallback: null,
  signals: [],
};
/** Compute regions for the given declaration */
export const compute: Server.ExecRequest<decl,null>= compute_internal;

const regions_internal: Server.GetRequest<decl,region[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.region.regions',
  input: jDecl,
  output: Json.jArray(jRegion),
  fallback: [],
  signals: [ { name: 'plugins.region.updated' } ],
};
/** Returns computed regions for the given declaration */
export const regions: Server.GetRequest<decl,region[]>= regions_internal;

const regionsAt_internal: Server.GetRequest<marker,region[]> = {
  kind: Server.RqKind.GET,
  name: 'plugins.region.regionsAt',
  input: jMarker,
  output: Json.jArray(jRegion),
  fallback: [],
  signals: [ { name: 'plugins.region.updated' } ],
};
/** Compute regions at the given marker program point */
export const regionsAt: Server.GetRequest<marker,region[]>= regionsAt_internal;

const localize_internal: Server.GetRequest<marker,node | undefined> = {
  kind: Server.RqKind.GET,
  name: 'plugins.region.localize',
  input: jMarker,
  output: Json.jOption(jNode),
  fallback: undefined,
  signals: [ { name: 'plugins.region.updated' } ],
};
/** Localize the marker in its map */
export const localize: Server.GetRequest<marker,node | undefined>= localize_internal;

/* ------------------------------------- */
