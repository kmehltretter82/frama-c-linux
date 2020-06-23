/* --- Generated Frama-C Server API --- */

/** Ast Services
   @packageDocumentation
   @module frama-c/kernel/ast
*/

import * as Json from 'dome/data/json'
import { tag } from 'api/kernel/data';
import { text } from 'api/kernel/data';


/** Ensures that AST is computed */


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


/** Markers data */


/** Signal for array [`markerData`](#markerdata)  */


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


/** Force full reload for array [`markerData`](#markerdata)
 */


/** Localizable AST markers */
export type marker =
  Json.Key<'stmt'> | Json.Key<'decl'> | Json.Key<'lval'> | Json.Key<'expr'> |
  Json.Key<'term'> | Json.Key<'global'> | Json.Key<'property'>;


/** Collect all functions in the AST */


/** Print the AST of a function */


/** AST Functions */


/** Signal for array [`functions`](#functions)  */


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


/** Force full reload for array [`functions`](#functions)
 */


/** Get textual information about a marker */


/** Get the currently analyzed source file names */


/** Set the source file names to analyze. */
