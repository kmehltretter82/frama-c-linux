/* --- Generated Frama-C Server API --- */

/**
   Ast Services
   @packageDocumentation
   @module frama-c/kernel/ast
*/

import * as Json from 'dome/data/json';
import * as Server from 'frama-c/server';

import { tag } from 'api/kernel/data';
import { text } from 'api/kernel/data';

/** Ensures that AST is computed */
export const compute: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'kernel.ast.compute',
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

/** Registered tags for the above type. */
export const markerKindTags: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.markerKindTags',
};

/** Markers data */
export const markerData: State.Array<'markerData',markerDataData> = {
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
  key: Json.Key<'markerData'>;
  /** Marker kind */
  kind: markerKind;
  /** Marker short name */
  name: string;
  /** Marker declaration or description */
  descr: string;
}

/** Data fetcher for array [`markerData`](#markerdata)  */
export const fetchMarkerData: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.fetchMarkerData',
};

/** Force full reload for array [`markerData`](#markerdata)  */
export const reloadMarkerData: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.reloadMarkerData',
};

/** Localizable AST markers */
export type marker =
  Json.Key<'stmt'> | Json.Key<'decl'> | Json.Key<'lval'> | Json.Key<'expr'> |
  Json.Key<'term'> | Json.Key<'global'> | Json.Key<'property'>;

/** Safe decoder for `marker` */
export const jMarkerSafe: Json.Safe<marker> =
  Json.jFail(jMarker,'Marker expected');

/** Loose decoder for `marker` */
export const jMarker: Json.Loose<marker> =
  Json.jUnion<Json.Key<'stmt'> | Json.Key<'decl'> | Json.Key<'lval'> |
              Json.Key<'expr'> | Json.Key<'term'> | Json.Key<'global'> |
              Json.Key<'property'>>(
    Json.jKey('stmt'),
    Json.jKey('decl'),
    Json.jKey('lval'),
    Json.jKey('expr'),
    Json.jKey('term'),
    Json.jKey('global'),
    Json.jKey('property'),
  );

/** Natural order for `marker` */

/** Collect all functions in the AST */
export const getFunctions: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getFunctions',
};

/** Print the AST of a function */
export const printFunction: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.printFunction',
};

/** AST Functions */
export const functions: State.Array<'functions',functionsData> = {
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
  key: Json.Key<'functions'>;
  /** Name */
  name: string;
  /** Signature */
  signature: string;
}

/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.fetchFunctions',
};

/** Force full reload for array [`functions`](#functions)  */
export const reloadFunctions: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.reloadFunctions',
};

/** Get textual information about a marker */
export const getInfo: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getInfo',
};

/** Get the currently analyzed source file names */
export const getFiles: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.getFiles',
};

/** Set the source file names to analyze. */
export const setFiles: Server.SetRequest = {
  kind: Server.RqKind.SET,
  name: 'kernel.ast.setFiles',
};

/* ------------------------------------- */
