/* --- Generated Frama-C Server API --- */

/** Ast Services
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


/** Returns all registered tags for the above type. */
export const markerKindTags: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.markerKindTags',
};


/** Markers data */


/** Signal for array [`markerData`](#markerdata)
 */
export const markerDataSig: Server.Signal = {
  name: 'kernel.ast.markerDataSig',
};


/** Data rows for array [`markerData`](#markerdata)
 */
export interface markerDataRow {
  /** Entry identifier. */
  key: Json.Key<'markerData'>;
  /** Marker kind */
  kind: markerKind;
  /** Marker short name */
  name: string;
  /** Marker declaration or description */
  descr: string;
}


/** Data fetcher for array [`markerData`](#markerdata)
 */
export const markerDataFetch: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.markerDataFetch',
};


/** Force full reload for array [`markerData`](#markerdata)
 */
export const markerDataReload: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.markerDataReload',
};


/** Localizable AST markers */
export type marker =
  Json.Key<'stmt'> | Json.Key<'decl'> | Json.Key<'lval'> | Json.Key<'expr'> |
  Json.Key<'term'> | Json.Key<'global'> | Json.Key<'property'>;


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


/** Signal for array [`functions`](#functions)
 */
export const functionsSig: Server.Signal = {
  name: 'kernel.ast.functionsSig',
};


/** Data rows for array [`functions`](#functions)
 */
export interface functionsRow {
  /** Entry identifier. */
  key: Json.Key<'functions'>;
  /** Name */
  name: string;
  /** Signature */
  signature: string;
}


/** Data fetcher for array [`functions`](#functions)
 */
export const functionsFetch: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.functionsFetch',
};


/** Force full reload for array [`functions`](#functions)
 */
export const functionsReload: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.ast.functionsReload',
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
