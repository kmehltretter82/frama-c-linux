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
   Ast Services
   @packageDocumentation
   @module frama-c/kernel/api/ast
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
import { byText } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jText } from 'frama-c/kernel/api/data';
//@ts-ignore
import { text } from 'frama-c/kernel/api/data';

const compute_internal: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name:   'kernel.ast.compute',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Ensures that AST is computed */
export const compute: Server.ExecRequest<null,null>= compute_internal;

/** Emitted when the AST has been changed */
export const changed: Server.Signal = {
  name: 'kernel.ast.changed',
};

/** Source file positions. */
export type source =
  { dir: string, base: string, file: string, line: number };

/** Decoder for `source` */
export const jSource: Json.Decoder<source> =
  Json.jObject({
    dir: Json.jString,
    base: Json.jString,
    file: Json.jString,
    line: Json.jNumber,
  });

/** Natural order for `source` */
export const bySource: Compare.Order<source> =
  Compare.byFields
    <{ dir: string, base: string, file: string, line: number }>({
    dir: Compare.string,
    base: Compare.string,
    file: Compare.string,
    line: Compare.number,
  });

/** Localizable AST markers */
export type marker = Json.key<'#marker'>;

/** Decoder for `marker` */
export const jMarker: Json.Decoder<marker> = Json.jKey<'#marker'>('#marker');

/** Natural order for `marker` */
export const byMarker: Compare.Order<marker> = Compare.string;

/** Location: function and marker */
export interface location {
  /** Function */
  fct: Json.key<'#fct'>;
  /** Marker */
  marker: marker;
}

/** Decoder for `location` */
export const jLocation: Json.Decoder<location> =
  Json.jObject({ fct: Json.jKey<'#fct'>('#fct'), marker: jMarker,});

/** Natural order for `location` */
export const byLocation: Compare.Order<location> =
  Compare.byFields
    <{ fct: Json.key<'#fct'>, marker: marker }>({
    fct: Compare.string,
    marker: byMarker,
  });

/** Data for array rows [`markerAttributes`](#markerattributes)  */
export interface markerAttributesData {
  /** Entry identifier. */
  key: string;
  /** Marker kind (short) */
  labelKind: string;
  /** Marker kind (long) */
  titleKind: string;
  /** Marker short name */
  name: string;
  /** Marker declaration or description */
  descr: string;
  /** Whether it is an l-value */
  isLval: boolean;
  /** Whether it is a function declaration or definition */
  isFunDecl: boolean;
  /** Whether it is a function symbol */
  isFun: boolean;
  /** Function scope of the marker, if applicable */
  scope?: string;
  /** Source location */
  sloc: source;
}

/** Decoder for `markerAttributesData` */
export const jMarkerAttributesData: Json.Decoder<markerAttributesData> =
  Json.jObject({
    key: Json.jString,
    labelKind: Json.jString,
    titleKind: Json.jString,
    name: Json.jString,
    descr: Json.jString,
    isLval: Json.jBoolean,
    isFunDecl: Json.jBoolean,
    isFun: Json.jBoolean,
    scope: Json.jOption(Json.jString),
    sloc: jSource,
  });

/** Natural order for `markerAttributesData` */
export const byMarkerAttributesData: Compare.Order<markerAttributesData> =
  Compare.byFields
    <{ key: string, labelKind: string, titleKind: string, name: string,
       descr: string, isLval: boolean, isFunDecl: boolean, isFun: boolean,
       scope?: string, sloc: source }>({
    key: Compare.string,
    labelKind: Compare.alpha,
    titleKind: Compare.alpha,
    name: Compare.alpha,
    descr: Compare.string,
    isLval: Compare.boolean,
    isFunDecl: Compare.boolean,
    isFun: Compare.boolean,
    scope: Compare.defined(Compare.string),
    sloc: bySource,
  });

/** Signal for array [`markerAttributes`](#markerattributes)  */
export const signalMarkerAttributes: Server.Signal = {
  name: 'kernel.ast.signalMarkerAttributes',
};

const reloadMarkerAttributes_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadMarkerAttributes',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`markerAttributes`](#markerattributes)  */
export const reloadMarkerAttributes: Server.GetRequest<null,null>= reloadMarkerAttributes_internal;

const fetchMarkerAttributes_internal: Server.GetRequest<
  number,
  { pending: number, updated: markerAttributesData[], removed: string[],
    reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchMarkerAttributes',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jNumber,
            updated: Json.jArray(jMarkerAttributesData),
            removed: Json.jArray(Json.jString),
            reload: Json.jBoolean,
          }),
  signals: [],
};
/** Data fetcher for array [`markerAttributes`](#markerattributes)  */
export const fetchMarkerAttributes: Server.GetRequest<
  number,
  { pending: number, updated: markerAttributesData[], removed: string[],
    reload: boolean }
  >= fetchMarkerAttributes_internal;

const markerAttributes_internal: State.Array<string,markerAttributesData> = {
  name: 'kernel.ast.markerAttributes',
  getkey: ((d:markerAttributesData) => d.key),
  signal: signalMarkerAttributes,
  fetch: fetchMarkerAttributes,
  reload: reloadMarkerAttributes,
  order: byMarkerAttributesData,
};
/** Marker attributes */
export const markerAttributes: State.Array<string,markerAttributesData> = markerAttributes_internal;

const getMainFunction_internal: Server.GetRequest<
  null,
  Json.key<'#fct'> |
  undefined
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getMainFunction',
  input:  Json.jNull,
  output: Json.jOption(Json.jKey<'#fct'>('#fct')),
  signals: [],
};
/** Get the current 'main' function. */
export const getMainFunction: Server.GetRequest<
  null,
  Json.key<'#fct'> |
  undefined
  >= getMainFunction_internal;

const getFunctions_internal: Server.GetRequest<null,Json.key<'#fct'>[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFunctions',
  input:  Json.jNull,
  output: Json.jArray(Json.jKey<'#fct'>('#fct')),
  signals: [],
};
/** Collect all functions in the AST */
export const getFunctions: Server.GetRequest<null,Json.key<'#fct'>[]>= getFunctions_internal;

const printFunction_internal: Server.GetRequest<Json.key<'#fct'>,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.printFunction',
  input:  Json.jKey<'#fct'>('#fct'),
  output: jText,
  signals: [],
};
/** Print the AST of a function */
export const printFunction: Server.GetRequest<Json.key<'#fct'>,text>= printFunction_internal;

/** Data for array rows [`functions`](#functions)  */
export interface functionsData {
  /** Entry identifier. */
  key: Json.key<'#functions'>;
  /** Name */
  name: string;
  /** Signature */
  signature: string;
  /** Is the function the main entry point */
  main?: boolean;
  /** Is the function defined? */
  defined?: boolean;
  /** Is the function from the Frama-C stdlib? */
  stdlib?: boolean;
  /** Is the function a Frama-C builtin? */
  builtin?: boolean;
  /** Source location */
  sloc: source;
}

/** Decoder for `functionsData` */
export const jFunctionsData: Json.Decoder<functionsData> =
  Json.jObject({
    key: Json.jKey<'#functions'>('#functions'),
    name: Json.jString,
    signature: Json.jString,
    main: Json.jOption(Json.jBoolean),
    defined: Json.jOption(Json.jBoolean),
    stdlib: Json.jOption(Json.jBoolean),
    builtin: Json.jOption(Json.jBoolean),
    sloc: jSource,
  });

/** Natural order for `functionsData` */
export const byFunctionsData: Compare.Order<functionsData> =
  Compare.byFields
    <{ key: Json.key<'#functions'>, name: string, signature: string,
       main?: boolean, defined?: boolean, stdlib?: boolean,
       builtin?: boolean, sloc: source }>({
    key: Compare.string,
    name: Compare.alpha,
    signature: Compare.string,
    main: Compare.defined(Compare.boolean),
    defined: Compare.defined(Compare.boolean),
    stdlib: Compare.defined(Compare.boolean),
    builtin: Compare.defined(Compare.boolean),
    sloc: bySource,
  });

/** Signal for array [`functions`](#functions)  */
export const signalFunctions: Server.Signal = {
  name: 'kernel.ast.signalFunctions',
};

const reloadFunctions_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadFunctions',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`functions`](#functions)  */
export const reloadFunctions: Server.GetRequest<null,null>= reloadFunctions_internal;

const fetchFunctions_internal: Server.GetRequest<
  number,
  { pending: number, updated: functionsData[],
    removed: Json.key<'#functions'>[], reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchFunctions',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jNumber,
            updated: Json.jArray(jFunctionsData),
            removed: Json.jArray(Json.jKey<'#functions'>('#functions')),
            reload: Json.jBoolean,
          }),
  signals: [],
};
/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest<
  number,
  { pending: number, updated: functionsData[],
    removed: Json.key<'#functions'>[], reload: boolean }
  >= fetchFunctions_internal;

const functions_internal: State.Array<Json.key<'#functions'>,functionsData> = {
  name: 'kernel.ast.functions',
  getkey: ((d:functionsData) => d.key),
  signal: signalFunctions,
  fetch: fetchFunctions,
  reload: reloadFunctions,
  order: byFunctionsData,
};
/** AST Functions */
export const functions: State.Array<Json.key<'#functions'>,functionsData> = functions_internal;

/** Updated AST information */
export const getInformationUpdate: Server.Signal = {
  name: 'kernel.ast.getInformationUpdate',
};

const getInformation_internal: Server.GetRequest<
  marker |
  undefined,
  { id: string, label: string, title: string, descr: string, text: text }[]
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getInformation',
  input:  Json.jOption(jMarker),
  output: Json.jArray(
            Json.jObject({
              id: Json.jString,
              label: Json.jString,
              title: Json.jString,
              descr: Json.jString,
              text: jText,
            })),
  signals: [ { name: 'kernel.ast.getInformationUpdate' } ],
};
/** Get available information about markers. When no marker is given, returns all kinds of information (with empty `descr` field). */
export const getInformation: Server.GetRequest<
  marker |
  undefined,
  { id: string, label: string, title: string, descr: string, text: text }[]
  >= getInformation_internal;

const getMarkerAt_internal: Server.GetRequest<
  [ string, number, number ],
  [ Json.key<'#fct'> | undefined, marker | undefined ]
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getMarkerAt',
  input:  Json.jTriple( Json.jString, Json.jNumber, Json.jNumber,),
  output: Json.jPair(
            Json.jOption(Json.jKey<'#fct'>('#fct')),
            Json.jOption(jMarker),
          ),
  signals: [],
};
/** Returns the marker and function at a source file position, if any. Input: file path, line and column. */
export const getMarkerAt: Server.GetRequest<
  [ string, number, number ],
  [ Json.key<'#fct'> | undefined, marker | undefined ]
  >= getMarkerAt_internal;

const getFiles_internal: Server.GetRequest<null,string[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFiles',
  input:  Json.jNull,
  output: Json.jArray(Json.jString),
  signals: [],
};
/** Get the currently analyzed source file names */
export const getFiles: Server.GetRequest<null,string[]>= getFiles_internal;

const setFiles_internal: Server.SetRequest<string[],null> = {
  kind: Server.RqKind.SET,
  name:   'kernel.ast.setFiles',
  input:  Json.jArray(Json.jString),
  output: Json.jNull,
  signals: [],
};
/** Set the source file names to analyze. */
export const setFiles: Server.SetRequest<string[],null>= setFiles_internal;

const parseTerm_internal: Server.GetRequest<
  { term: string, stmt: marker },
  marker |
  undefined
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.parseTerm',
  input:  Json.jObject({ term: Json.jString, stmt: jMarker,}),
  output: Json.jOption(jMarker),
  signals: [],
};
/** Parse an ACSL Term and returns the associated marker */
export const parseTerm: Server.GetRequest<
  { term: string, stmt: marker },
  marker |
  undefined
  >= parseTerm_internal;

/* ------------------------------------- */
