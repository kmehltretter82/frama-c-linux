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
  name: 'kernel.ast.compute',
  input: Json.jNull,
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
  /** Declaration's marker */
  self: marker;
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
    self: jMarker,
    name: Json.jString,
    label: Json.jString,
    source: jSource,
  });

/** Natural order for `declAttributesData` */
export const byDeclAttributesData: Compare.Order<declAttributesData> =
  Compare.byFields
    <{ decl: decl, kind: declKind, self: marker, name: string, label: string,
       source: source }>({
    decl: byDecl,
    kind: byDeclKind,
    self: byMarker,
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
  name: 'kernel.ast.reloadDeclAttributes',
  input: Json.jNull,
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
  name: 'kernel.ast.fetchDeclAttributes',
  input: Json.jNumber,
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
  { decl: declDefault, kind: declKindDefault, self: markerDefault, name: '',
    label: '', source: sourceDefault };

const printDeclaration_internal: Server.GetRequest<decl,text> = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.printDeclaration',
  input: jDecl,
  output: jText,
  signals: [ { name: 'kernel.ast.changed' } ],
};
/** Prints an AST Declaration */
export const printDeclaration: Server.GetRequest<decl,text>= printDeclaration_internal;

/** Marker kind */
export type markerKind =
  Json.key<'#STMT'> | Json.key<'#LFUN'> | Json.key<'#DFUN'> |
  Json.key<'#LVAR'> | Json.key<'#DVAR'> | Json.key<'#LVAL'> |
  Json.key<'#EXP'> | Json.key<'#TERM'> | Json.key<'#TYPE'> |
  Json.key<'#PROPERTY'> | Json.key<'#DECLARATION'>;

/** Decoder for `markerKind` */
export const jMarkerKind: Json.Decoder<markerKind> =
  Json.jUnion<Json.key<'#STMT'> | Json.key<'#LFUN'> | Json.key<'#DFUN'> |
              Json.key<'#LVAR'> | Json.key<'#DVAR'> | Json.key<'#LVAL'> |
              Json.key<'#EXP'> | Json.key<'#TERM'> | Json.key<'#TYPE'> |
              Json.key<'#PROPERTY'> | Json.key<'#DECLARATION'>>(
    Json.jKey<'#STMT'>('#STMT'),
    Json.jKey<'#LFUN'>('#LFUN'),
    Json.jKey<'#DFUN'>('#DFUN'),
    Json.jKey<'#LVAR'>('#LVAR'),
    Json.jKey<'#DVAR'>('#DVAR'),
    Json.jKey<'#LVAL'>('#LVAL'),
    Json.jKey<'#EXP'>('#EXP'),
    Json.jKey<'#TERM'>('#TERM'),
    Json.jKey<'#TYPE'>('#TYPE'),
    Json.jKey<'#PROPERTY'>('#PROPERTY'),
    Json.jKey<'#DECLARATION'>('#DECLARATION'),
  );

/** Natural order for `markerKind` */
export const byMarkerKind: Compare.Order<markerKind> = Compare.structural;

/** Default value for `markerKind` */
export const markerKindDefault: markerKind = Json.jKey<'#STMT'>('#STMT')('');

/** Data for array rows [`markerAttributes`](#markerattributes)  */
export interface markerAttributesData {
  /** Entry identifier. */
  marker: marker;
  /** Marker kind (key) */
  kind: markerKind;
  /** Marker Scope (where it is printed in) */
  scope?: decl;
  /** Marker's Target Definition (when applicable) */
  definition?: marker;
  /** Marker kind label */
  labelKind: string;
  /** Marker kind title */
  titleKind: string;
  /** Marker identifier (when applicable) */
  name?: string;
  /** Marker description */
  descr: string;
  /** Source location */
  sloc?: source;
}

/** Decoder for `markerAttributesData` */
export const jMarkerAttributesData: Json.Decoder<markerAttributesData> =
  Json.jObject({
    marker: jMarker,
    kind: jMarkerKind,
    scope: Json.jOption(jDecl),
    definition: Json.jOption(jMarker),
    labelKind: Json.jString,
    titleKind: Json.jString,
    name: Json.jOption(Json.jString),
    descr: Json.jString,
    sloc: Json.jOption(jSource),
  });

/** Natural order for `markerAttributesData` */
export const byMarkerAttributesData: Compare.Order<markerAttributesData> =
  Compare.byFields
    <{ marker: marker, kind: markerKind, scope?: decl, definition?: marker,
       labelKind: string, titleKind: string, name?: string, descr: string,
       sloc?: source }>({
    marker: byMarker,
    kind: byMarkerKind,
    scope: Compare.defined(byDecl),
    definition: Compare.defined(byMarker),
    labelKind: Compare.alpha,
    titleKind: Compare.alpha,
    name: Compare.defined(Compare.alpha),
    descr: Compare.string,
    sloc: Compare.defined(bySource),
  });

/** Signal for array [`markerAttributes`](#markerattributes)  */
export const signalMarkerAttributes: Server.Signal = {
  name: 'kernel.ast.signalMarkerAttributes',
};

const reloadMarkerAttributes_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.reloadMarkerAttributes',
  input: Json.jNull,
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
  name: 'kernel.ast.fetchMarkerAttributes',
  input: Json.jNumber,
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
  { marker: markerDefault, kind: markerKindDefault, scope: undefined,
    definition: undefined, labelKind: '', titleKind: '', name: undefined,
    descr: '', sloc: undefined };

const getMainFunction_internal: Server.GetRequest<null,decl | undefined> = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getMainFunction',
  input: Json.jNull,
  output: Json.jOption(jDecl),
  signals: [],
};
/** Get the current 'main' function. */
export const getMainFunction: Server.GetRequest<null,decl | undefined>= getMainFunction_internal;

const getFunctions_internal: Server.GetRequest<null,decl[]> = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getFunctions',
  input: Json.jNull,
  output: Json.jArray(jDecl),
  signals: [],
};
/** Collect all functions in the AST */
export const getFunctions: Server.GetRequest<null,decl[]>= getFunctions_internal;

/** Data for array rows [`functions`](#functions)  */
export interface functionsData {
  /** Entry identifier. */
  key: Json.key<'#functions'>;
  /** Declaration Tag */
  decl: decl;
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
    decl: jDecl,
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
    <{ key: Json.key<'#functions'>, decl: decl, name: string,
       signature: string, main?: boolean, defined?: boolean,
       stdlib?: boolean, builtin?: boolean, extern?: boolean, sloc: source }>({
    key: Compare.string,
    decl: byDecl,
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
  name: 'kernel.ast.reloadFunctions',
  input: Json.jNull,
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
  name: 'kernel.ast.fetchFunctions',
  input: Json.jNumber,
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
  { key: Json.jKey<'#functions'>('#functions')(''), decl: declDefault,
    name: '', signature: '', main: undefined, defined: undefined,
    stdlib: undefined, builtin: undefined, extern: undefined,
    sloc: sourceDefault };

/** Data for array rows [`globals`](#globals)  */
export interface globalsData {
  /** Entry identifier. */
  key: Json.key<'#globals'>;
  /** Declaration Tag */
  decl: decl;
  /** Name */
  name: string;
  /** Type */
  type: string;
  /** Is the variable from the Frama-C stdlib? */
  stdlib: boolean;
  /** Is the variable extern? */
  extern: boolean;
  /** Is the variable const? */
  const: boolean;
  /** Is the variable volatile? */
  volatile: boolean;
  /** Is the variable ghost? */
  ghost: boolean;
  /** Is the variable explicitly initialized? */
  init: boolean;
  /** Is the variable in the source code? */
  source: boolean;
  /** Source location */
  sloc: source;
}

/** Decoder for `globalsData` */
export const jGlobalsData: Json.Decoder<globalsData> =
  Json.jObject({
    key: Json.jKey<'#globals'>('#globals'),
    decl: jDecl,
    name: Json.jString,
    type: Json.jString,
    stdlib: Json.jBoolean,
    extern: Json.jBoolean,
    const: Json.jBoolean,
    volatile: Json.jBoolean,
    ghost: Json.jBoolean,
    init: Json.jBoolean,
    source: Json.jBoolean,
    sloc: jSource,
  });

/** Natural order for `globalsData` */
export const byGlobalsData: Compare.Order<globalsData> =
  Compare.byFields
    <{ key: Json.key<'#globals'>, decl: decl, name: string, type: string,
       stdlib: boolean, extern: boolean, const: boolean, volatile: boolean,
       ghost: boolean, init: boolean, source: boolean, sloc: source }>({
    key: Compare.string,
    decl: byDecl,
    name: Compare.alpha,
    type: Compare.string,
    stdlib: Compare.boolean,
    extern: Compare.boolean,
    const: Compare.boolean,
    volatile: Compare.boolean,
    ghost: Compare.boolean,
    init: Compare.boolean,
    source: Compare.boolean,
    sloc: bySource,
  });

/** Signal for array [`globals`](#globals)  */
export const signalGlobals: Server.Signal = {
  name: 'kernel.ast.signalGlobals',
};

const reloadGlobals_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.reloadGlobals',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`globals`](#globals)  */
export const reloadGlobals: Server.GetRequest<null,null>= reloadGlobals_internal;

const fetchGlobals_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#globals'>[], updated: globalsData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.fetchGlobals',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(Json.jKey<'#globals'>('#globals')),
            updated: Json.jArray(jGlobalsData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`globals`](#globals)  */
export const fetchGlobals: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#globals'>[], updated: globalsData[],
    pending: number }
  >= fetchGlobals_internal;

const globals_internal: State.Array<Json.key<'#globals'>,globalsData> = {
  name: 'kernel.ast.globals',
  getkey: ((d:globalsData) => d.key),
  signal: signalGlobals,
  fetch: fetchGlobals,
  reload: reloadGlobals,
  order: byGlobalsData,
};
/** AST global variables */
export const globals: State.Array<Json.key<'#globals'>,globalsData> = globals_internal;

/** Default value for `globalsData` */
export const globalsDataDefault: globalsData =
  { key: Json.jKey<'#globals'>('#globals')(''), decl: declDefault, name: '',
    type: '', stdlib: false, extern: false, const: false, volatile: false,
    ghost: false, init: false, source: false, sloc: sourceDefault };

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
  name: 'kernel.ast.getInformation',
  input: Json.jOption(jMarker),
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
  { file: string, line: number, column: number },
  marker |
  undefined
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getMarkerAt',
  input: Json.jObject({
           file: Json.jString,
           line: Json.jNumber,
           column: Json.jNumber,
         }),
  output: Json.jOption(jMarker),
  signals: [ { name: 'kernel.ast.changed' } ],
};
/** Returns the marker and function at a source file position, if any. Input: file path, line and column. File can be empty, in case no marker is returned. */
export const getMarkerAt: Server.GetRequest<
  { file: string, line: number, column: number },
  marker |
  undefined
  >= getMarkerAt_internal;

const getFiles_internal: Server.GetRequest<null,string[]> = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getFiles',
  input: Json.jNull,
  output: Json.jArray(Json.jString),
  signals: [],
};
/** Get the currently analyzed source file names */
export const getFiles: Server.GetRequest<null,string[]>= getFiles_internal;

const setFiles_internal: Server.SetRequest<string[],null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.ast.setFiles',
  input: Json.jArray(Json.jString),
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
  name: 'kernel.ast.parseExpr',
  input: Json.jObject({ stmt: jMarker, term: Json.jString,}),
  output: jMarker,
  signals: [],
};
/** Parse a C expression and returns the associated marker */
export const parseExpr: Server.GetRequest<
  { stmt: marker, term: string },
  marker
  >= parseExpr_internal;

const parseLval_internal: Server.GetRequest<
  { stmt: marker, term: string },
  marker
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.parseLval',
  input: Json.jObject({ stmt: jMarker, term: Json.jString,}),
  output: jMarker,
  signals: [],
};
/** Parse a C lvalue and returns the associated marker */
export const parseLval: Server.GetRequest<
  { stmt: marker, term: string },
  marker
  >= parseLval_internal;

/* ------------------------------------- */
