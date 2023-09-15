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
//@ts-ignore
import { textDefault } from 'frama-c/kernel/api/data';

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

/** Default value for `source` */
export const sourceDefault: source =
  { dir: '', base: '', file: '', line: 0 };

/** Function names */
export type fct = Json.key<'#fct'>;

/** Decoder for `fct` */
export const jFct: Json.Decoder<fct> = Json.jKey<'#fct'>('#fct');

/** Natural order for `fct` */
export const byFct: Compare.Order<fct> = Compare.string;

/** Default value for `fct` */
export const fctDefault: fct = Json.jKey<'#fct'>('#fct')('');

/** AST Declarations markers */
export type decl = Json.key<'#decl'>;

/** Decoder for `decl` */
export const jDecl: Json.Decoder<decl> = Json.jKey<'#decl'>('#decl');

/** Natural order for `decl` */
export const byDecl: Compare.Order<decl> = Compare.string;

/** Default value for `decl` */
export const declDefault: decl = Json.jKey<'#decl'>('#decl')('');

/** Localizable AST markers */
export type marker = Json.key<'#marker'>;

/** Decoder for `marker` */
export const jMarker: Json.Decoder<marker> = Json.jKey<'#marker'>('#marker');

/** Natural order for `marker` */
export const byMarker: Compare.Order<marker> = Compare.string;

/** Default value for `marker` */
export const markerDefault: marker = Json.jKey<'#marker'>('#marker')('');

/** Location: function and marker */
export type location = { fct: fct, marker: marker };

/** Decoder for `location` */
export const jLocation: Json.Decoder<location> =
  Json.jObject({ fct: jFct, marker: jMarker,});

/** Natural order for `location` */
export const byLocation: Compare.Order<location> =
  Compare.byFields
    <{ fct: fct, marker: marker }>({
    fct: byFct,
    marker: byMarker,
  });

/** Default value for `location` */
export const locationDefault: location =
  { fct: fctDefault, marker: markerDefault };

/** Declaration kind */
export type declKind =
  Json.key<'#ENUM'> | Json.key<'#UNION'> | Json.key<'#STRUCT'> |
  Json.key<'#TYPEDEF'> | Json.key<'#GLOBAL'> | Json.key<'#FUNCTION'>;

/** Decoder for `declKind` */
export const jDeclKind: Json.Decoder<declKind> =
  Json.jUnion<Json.key<'#ENUM'> | Json.key<'#UNION'> | Json.key<'#STRUCT'> |
              Json.key<'#TYPEDEF'> | Json.key<'#GLOBAL'> |
              Json.key<'#FUNCTION'>>(
    Json.jKey<'#ENUM'>('#ENUM'),
    Json.jKey<'#UNION'>('#UNION'),
    Json.jKey<'#STRUCT'>('#STRUCT'),
    Json.jKey<'#TYPEDEF'>('#TYPEDEF'),
    Json.jKey<'#GLOBAL'>('#GLOBAL'),
    Json.jKey<'#FUNCTION'>('#FUNCTION'),
  );

/** Natural order for `declKind` */
export const byDeclKind: Compare.Order<declKind> = Compare.structural;

/** Default value for `declKind` */
export const declKindDefault: declKind = Json.jKey<'#ENUM'>('#ENUM')('');

/** Data for array rows [`declAttributes`](#declattributes)  */
export interface declAttributesData {
  /** Entry identifier. */
  decl: decl;
  /** Declaration kind */
  kind: declKind;
  /** Declaration identifier */
  name: string;
  /** Declaration label (uncapitalized kind & name) */
  label: string;
  /** Source location */
  source: source;
}

/** Decoder for `declAttributesData` */
export const jDeclAttributesData: Json.Decoder<declAttributesData> =
  Json.jObject({
    decl: jDecl,
    kind: jDeclKind,
    name: Json.jString,
    label: Json.jString,
    source: jSource,
  });

/** Natural order for `declAttributesData` */
export const byDeclAttributesData: Compare.Order<declAttributesData> =
  Compare.byFields
    <{ decl: decl, kind: declKind, name: string, label: string,
       source: source }>({
    decl: byDecl,
    kind: byDeclKind,
    name: Compare.string,
    label: Compare.string,
    source: bySource,
  });

/** Signal for array [`declAttributes`](#declattributes)  */
export const signalDeclAttributes: Server.Signal = {
  name: 'kernel.ast.signalDeclAttributes',
};

const reloadDeclAttributes_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadDeclAttributes',
  input:  Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`declAttributes`](#declattributes)  */
export const reloadDeclAttributes: Server.GetRequest<null,null>= reloadDeclAttributes_internal;

const fetchDeclAttributes_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: decl[], updated: declAttributesData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchDeclAttributes',
  input:  Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jDecl),
            updated: Json.jArray(jDeclAttributesData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`declAttributes`](#declattributes)  */
export const fetchDeclAttributes: Server.GetRequest<
  number,
  { reload: boolean, removed: decl[], updated: declAttributesData[],
    pending: number }
  >= fetchDeclAttributes_internal;

const declAttributes_internal: State.Array<decl,declAttributesData> = {
  name: 'kernel.ast.declAttributes',
  getkey: ((d:declAttributesData) => d.decl),
  signal: signalDeclAttributes,
  fetch: fetchDeclAttributes,
  reload: reloadDeclAttributes,
  order: byDeclAttributesData,
};
/** Declaration attributes */
export const declAttributes: State.Array<decl,declAttributesData> = declAttributes_internal;

/** Default value for `declAttributesData` */
export const declAttributesDataDefault: declAttributesData =
  { decl: declDefault, kind: declKindDefault, name: '', label: '',
    source: sourceDefault };

const printDeclaration_internal: Server.GetRequest<decl,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.printDeclaration',
  input:  jDecl,
  output: jText,
  signals: [ { name: 'kernel.ast.changed' } ],
};
/** Prints an AST Declaration */
export const printDeclaration: Server.GetRequest<decl,text>= printDeclaration_internal;

/** Data for array rows [`markerAttributes`](#markerattributes)  */
export interface markerAttributesData {
  /** Entry identifier. */
  marker: marker;
  /** Marker kind (short) */
  labelKind: string;
  /** Marker kind (long) */
  titleKind: string;
  /** Marker short name (identifier if any) */
  name: string;
  /** Marker description */
  descr: string;
  /** Declaration scope */
  decl?: decl;
  /** Whether it is an l-value */
  isLval: boolean;
  /** Whether it is a function symbol */
  isFunction: boolean;
  /** Whether it is a function pointer */
  isFunctionPointer: boolean;
  /** Whether it is a function declaration */
  isFunDecl: boolean;
  /** Function scope of the marker, if applicable */
  scope?: string;
  /** Source location */
  sloc?: source;
}

/** Decoder for `markerAttributesData` */
export const jMarkerAttributesData: Json.Decoder<markerAttributesData> =
  Json.jObject({
    marker: jMarker,
    labelKind: Json.jString,
    titleKind: Json.jString,
    name: Json.jString,
    descr: Json.jString,
    decl: Json.jOption(jDecl),
    isLval: Json.jBoolean,
    isFunction: Json.jBoolean,
    isFunctionPointer: Json.jBoolean,
    isFunDecl: Json.jBoolean,
    scope: Json.jOption(Json.jString),
    sloc: Json.jOption(jSource),
  });

/** Natural order for `markerAttributesData` */
export const byMarkerAttributesData: Compare.Order<markerAttributesData> =
  Compare.byFields
    <{ marker: marker, labelKind: string, titleKind: string, name: string,
       descr: string, decl?: decl, isLval: boolean, isFunction: boolean,
       isFunctionPointer: boolean, isFunDecl: boolean, scope?: string,
       sloc?: source }>({
    marker: byMarker,
    labelKind: Compare.alpha,
    titleKind: Compare.alpha,
    name: Compare.alpha,
    descr: Compare.string,
    decl: Compare.defined(byDecl),
    isLval: Compare.boolean,
    isFunction: Compare.boolean,
    isFunctionPointer: Compare.boolean,
    isFunDecl: Compare.boolean,
    scope: Compare.defined(Compare.string),
    sloc: Compare.defined(bySource),
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
  { reload: boolean, removed: marker[], updated: markerAttributesData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchMarkerAttributes',
  input:  Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(jMarker),
            updated: Json.jArray(jMarkerAttributesData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`markerAttributes`](#markerattributes)  */
export const fetchMarkerAttributes: Server.GetRequest<
  number,
  { reload: boolean, removed: marker[], updated: markerAttributesData[],
    pending: number }
  >= fetchMarkerAttributes_internal;

const markerAttributes_internal: State.Array<marker,markerAttributesData> = {
  name: 'kernel.ast.markerAttributes',
  getkey: ((d:markerAttributesData) => d.marker),
  signal: signalMarkerAttributes,
  fetch: fetchMarkerAttributes,
  reload: reloadMarkerAttributes,
  order: byMarkerAttributesData,
};
/** Marker attributes */
export const markerAttributes: State.Array<marker,markerAttributesData> = markerAttributes_internal;

/** Default value for `markerAttributesData` */
export const markerAttributesDataDefault: markerAttributesData =
  { marker: markerDefault, labelKind: '', titleKind: '', name: '', descr: '',
    decl: undefined, isLval: false, isFunction: false,
    isFunctionPointer: false, isFunDecl: false, scope: undefined,
    sloc: undefined };

const getMainFunction_internal: Server.GetRequest<null,fct | undefined> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getMainFunction',
  input:  Json.jNull,
  output: Json.jOption(jFct),
  signals: [],
};
/** Get the current 'main' function. */
export const getMainFunction: Server.GetRequest<null,fct | undefined>= getMainFunction_internal;

const getFunctions_internal: Server.GetRequest<null,fct[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFunctions',
  input:  Json.jNull,
  output: Json.jArray(jFct),
  signals: [],
};
/** Collect all functions in the AST */
export const getFunctions: Server.GetRequest<null,fct[]>= getFunctions_internal;

const printFunction_internal: Server.GetRequest<fct,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.printFunction',
  input:  jFct,
  output: jText,
  signals: [ { name: 'kernel.ast.changed' } ],
};
/** Print the AST of a function */
export const printFunction: Server.GetRequest<fct,text>= printFunction_internal;

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
  /** Is the function extern? */
  extern?: boolean;
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
    extern: Json.jOption(Json.jBoolean),
    sloc: jSource,
  });

/** Natural order for `functionsData` */
export const byFunctionsData: Compare.Order<functionsData> =
  Compare.byFields
    <{ key: Json.key<'#functions'>, name: string, signature: string,
       main?: boolean, defined?: boolean, stdlib?: boolean,
       builtin?: boolean, extern?: boolean, sloc: source }>({
    key: Compare.string,
    name: Compare.alpha,
    signature: Compare.string,
    main: Compare.defined(Compare.boolean),
    defined: Compare.defined(Compare.boolean),
    stdlib: Compare.defined(Compare.boolean),
    builtin: Compare.defined(Compare.boolean),
    extern: Compare.defined(Compare.boolean),
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
  { reload: boolean, removed: Json.key<'#functions'>[],
    updated: functionsData[], pending: number }
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchFunctions',
  input:  Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(Json.jKey<'#functions'>('#functions')),
            updated: Json.jArray(jFunctionsData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#functions'>[],
    updated: functionsData[], pending: number }
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

/** Default value for `functionsData` */
export const functionsDataDefault: functionsData =
  { key: Json.jKey<'#functions'>('#functions')(''), name: '', signature: '',
    main: undefined, defined: undefined, stdlib: undefined,
    builtin: undefined, extern: undefined, sloc: sourceDefault };

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
  [ fct | undefined, marker | undefined ]
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getMarkerAt',
  input:  Json.jTriple( Json.jString, Json.jNumber, Json.jNumber,),
  output: Json.jPair( Json.jOption(jFct), Json.jOption(jMarker),),
  signals: [],
};
/** Returns the marker and function at a source file position, if any. Input: file path, line and column. */
export const getMarkerAt: Server.GetRequest<
  [ string, number, number ],
  [ fct | undefined, marker | undefined ]
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

const parseExpr_internal: Server.GetRequest<
  { stmt: marker, term: string },
  marker
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.parseExpr',
  input:  Json.jObject({ stmt: jMarker, term: Json.jString,}),
  output: jMarker,
  signals: [],
};
/** Parse a C expression and returns the associated marker */
export const parseExpr: Server.GetRequest<
  { stmt: marker, term: string },
  marker
  >= parseExpr_internal;

/* ------------------------------------- */
