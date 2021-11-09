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
   Physical Units
   @packageDocumentation
   @module frama-c/api/plugins/unitcheck
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
import { byText } from 'frama-c/api/kernel/data';
//@ts-ignore
import { jText } from 'frama-c/api/kernel/data';
//@ts-ignore
import { jTextSafe } from 'frama-c/api/kernel/data';
//@ts-ignore
import { text } from 'frama-c/api/kernel/data';

const getMarker_internal: Server.GetRequest<marker,text> = {
  kind: Server.RqKind.GET,
  name:   'plugins.unitcheck.getMarker',
  input:  jMarker,
  output: jText,
  signals: [],
};
/** Unit of marker, if any */
export const getMarker: Server.GetRequest<marker,text>= getMarker_internal;

const getSignature_internal: Server.GetRequest<
  Json.key<'#fct'>,
  { result: { ctype: text, units: text },
    locals: { marker: marker, name: string, ctype: text, units: text }[],
    formals: { marker: marker, name: string, ctype: text, units: text }[] }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.unitcheck.getSignature',
  input:  Json.jKey<'#fct'>('#fct'),
  output: Json.jObject({
            result: Json.jFail(
                      Json.jObject({ ctype: jTextSafe, units: jTextSafe,}),
                      'Record expected'),
            locals: Json.jList(
                      Json.jObject({
                        marker: jMarkerSafe,
                        name: Json.jFail(Json.jString,'String expected'),
                        ctype: jTextSafe,
                        units: jTextSafe,
                      })),
            formals: Json.jList(
                       Json.jObject({
                         marker: jMarkerSafe,
                         name: Json.jFail(Json.jString,'String expected'),
                         ctype: jTextSafe,
                         units: jTextSafe,
                       })),
          }),
  signals: [ { name: 'kernel.ast.getInformationsUpdate' } ],
};
/** Return units of function */
export const getSignature: Server.GetRequest<
  Json.key<'#fct'>,
  { result: { ctype: text, units: text },
    locals: { marker: marker, name: string, ctype: text, units: text }[],
    formals: { marker: marker, name: string, ctype: text, units: text }[] }
  >= getSignature_internal;

/* ------------------------------------- */
