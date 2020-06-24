/* --- Generated Frama-C Server API --- */

/**
   Ast Services
   @packageDocumentation
   @module frama-c/kernel/ast
*/

import * as Json from 'dome/data/json';
import * as Compare from 'dome/data/compare';
import * as Server from 'frama-c/server';
import * as State from 'frama-c/states';

import { byTag } from 'api/kernel/data';
import { byText } from 'api/kernel/data';
import { jTag } from 'api/kernel/data';
import { jTagSafe } from 'api/kernel/data';
import { jText } from 'api/kernel/data';
import { jTextSafe } from 'api/kernel/data';
import { tag } from 'api/kernel/data';
import { text } from 'api/kernel/data';

/** Ensures that AST is computed */
export const compute: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name:   'kernel.ast.compute',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Marker kind */
export enum markerKind {
  /** Expression */
  expression = 'expression';
  /** Lvalue */
  lvalue = 'lvalue';
  /** Variable */
  variable = 'variable';
  /** Function */
  function = 'function';
  /** Declaration */
  declaration = 'declaration';
  /** Statement */
  statement = 'statement';
  /** Global */
  global = 'global';
  /** Term */
  term = 'term';
  /** Property */
  property = 'property';
}

/** Safe decoder for `markerKind` */
export const jMarkerKindSafe: Json.Safe<markerKind> =
  Json.jFail(Json.jEnum(markerKind),'kernel.ast.markerKind expected');

/** Loose decoder for `markerKind` */
export const jMarkerKind: Json.Loose<markerKind> = Json.jEnum(markerKind);

/** Natural order for `markerKind` */
export const byMarkerKind: Compare.Order<markerKind> =
  Compare.byEnym(markerKind);

/** Registered tags for the above type. */
export const markerKindTags: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.markerKindTags',
  input:  Json.jNull,
  output: Json.jList(jTag),
};

/** Markers data */
export const markerData: State.Array<'#markerData',markerDataData> = {
  name: 'kernel.ast.markerData',
  key: 'key',
  signal: signalMarkerData,
  fetch: fetchMarkerData,
  reload: reloadMarkerData,
};

/** Signal for array [`markerData`](#markerdata)  */
export const signalMarkerData: Server.Signal = {
  name: 'kernel.ast.signalMarkerData',
};

/** Data for array rows [`markerData`](#markerdata)  */
export interface markerDataData {
  /** Entry identifier. */
  key: Json.Key<'#markerData'>;
  /** Marker kind */
  kind: markerKind;
  /** Marker short name */
  name: string;
  /** Marker declaration or description */
  descr: string;
}

/** Data fetcher for array [`markerData`](#markerdata)  */
export const fetchMarkerData: Server.GetRequest<number,
  { pending: number, updated: markerDataData[],
    removed: Json.Key<'#markerData'>[], reload: boolean }> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchMarkerData',
  input:  Json.jNumber,
  output: Json.jTry(
            Json.jObject({
              pending: Json.jFail(Json.jNumber,'Number expected'),
              updated: Json.jList(jMarkerDataData),
              removed: Json.jList(Json.jKey('#markerData')),
              reload: Json.jFail(Json.jBoolean,'Boolean expected'),
            })),
};

/** Force full reload for array [`markerData`](#markerdata)  */
export const reloadMarkerData: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadMarkerData',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Localizable AST markers */
export type marker =
  Json.Key<'#stmt'> | Json.Key<'#decl'> | Json.Key<'#lval'> |
  Json.Key<'#expr'> | Json.Key<'#term'> | Json.Key<'#global'> |
  Json.Key<'#property'>;

/** Safe decoder for `marker` */
export const jMarkerSafe: Json.Safe<marker> =
  Json.jFail(jMarker,'Marker expected');

/** Loose decoder for `marker` */
export const jMarker: Json.Loose<marker> =
  Json.jUnion<Json.Key<'#stmt'> | Json.Key<'#decl'> | Json.Key<'#lval'> |
              Json.Key<'#expr'> | Json.Key<'#term'> | Json.Key<'#global'> |
              Json.Key<'#property'>>(
    Json.jKey('#stmt'),
    Json.jKey('#decl'),
    Json.jKey('#lval'),
    Json.jKey('#expr'),
    Json.jKey('#term'),
    Json.jKey('#global'),
    Json.jKey('#property'),
  );

/** Natural order for `marker` */
export const byMarker: Compare.Order<marker> = Compare.structural;

/** Collect all functions in the AST */
export const getFunctions: Server.GetRequest<null,Json.Key<'#fct'>[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFunctions',
  input:  Json.jNull,
  output: Json.jList(Json.jKey('#fct')),
};

/** Print the AST of a function */
export const printFunction: Server.GetRequest<Json.Key<'#fct'>,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.printFunction',
  input:  Json.jKey('#fct'),
  output: jText,
};

/** AST Functions */
export const functions: State.Array<'#functions',functionsData> = {
  name: 'kernel.ast.functions',
  key: 'key',
  signal: signalFunctions,
  fetch: fetchFunctions,
  reload: reloadFunctions,
};

/** Signal for array [`functions`](#functions)  */
export const signalFunctions: Server.Signal = {
  name: 'kernel.ast.signalFunctions',
};

/** Data for array rows [`functions`](#functions)  */
export interface functionsData {
  /** Entry identifier. */
  key: Json.Key<'#functions'>;
  /** Name */
  name: string;
  /** Signature */
  signature: string;
}

/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest<number,
  { pending: number, updated: functionsData[],
    removed: Json.Key<'#functions'>[], reload: boolean }> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchFunctions',
  input:  Json.jNumber,
  output: Json.jTry(
            Json.jObject({
              pending: Json.jFail(Json.jNumber,'Number expected'),
              updated: Json.jList(jFunctionsData),
              removed: Json.jList(Json.jKey('#functions')),
              reload: Json.jFail(Json.jBoolean,'Boolean expected'),
            })),
};

/** Force full reload for array [`functions`](#functions)  */
export const reloadFunctions: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadFunctions',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Get textual information about a marker */
export const getInfo: Server.GetRequest<marker,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getInfo',
  input:  jMarker,
  output: jText,
};

/** Get the currently analyzed source file names */
export const getFiles: Server.GetRequest<null,string[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFiles',
  input:  Json.jNull,
  output: Json.jList(Json.jString),
};

/** Set the source file names to analyze. */
export const setFiles: Server.SetRequest<string[],null> = {
  kind: Server.RqKind.SET,
  name:   'kernel.ast.setFiles',
  input:  Json.jList(Json.jString),
  output: Json.jNull,
};

/* ------------------------------------- */
