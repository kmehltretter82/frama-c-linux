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
   Studia
   @packageDocumentation
   @module frama-c/plugins/studia/api/studia
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
import { markerDefault } from 'frama-c/kernel/api/ast';

/** Statements that read or write a location. */
export interface effects {
  /** List of statements with direct effect. */
  direct: marker[];
  /** List of statements with indirect effect. */
  indirect: marker[];
}

/** Decoder for `effects` */
export const jEffects: Json.Decoder<effects> =
  Json.jObject({
    direct: Json.jArray(jMarker),
    indirect: Json.jArray(jMarker),
  });

/** Natural order for `effects` */
export const byEffects: Compare.Order<effects> =
  Compare.byFields
    <{ direct: marker[], indirect: marker[] }>({
    direct: Compare.array(byMarker),
    indirect: Compare.array(byMarker),
  });

/** Default value for `effects` */
export const effectsDefault: effects = { direct: [], indirect: [] };

const getReadsLval_internal: Server.GetRequest<marker,effects> = {
  kind: Server.RqKind.GET,
  name: 'plugins.studia.studia.getReadsLval',
  input: jMarker,
  output: jEffects,
  signals: [],
};
/** Get the list of statements that read a lval. */
export const getReadsLval: Server.GetRequest<marker,effects>= getReadsLval_internal;

const getWritesLval_internal: Server.GetRequest<marker,effects> = {
  kind: Server.RqKind.GET,
  name: 'plugins.studia.studia.getWritesLval',
  input: jMarker,
  output: jEffects,
  signals: [],
};
/** Get the list of statements that write a lval. */
export const getWritesLval: Server.GetRequest<marker,effects>= getWritesLval_internal;

/* ------------------------------------- */
