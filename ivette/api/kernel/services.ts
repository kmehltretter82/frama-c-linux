/* --- Generated Frama-C Server API --- */

/** Kernel Services
   @packageDocumentation
   @module frama-c/kernel/services
*/

import * as Json from 'dome/data/json'
import { tag } from 'api/kernel/data';


/** Frama-C Kernel configuration */


/** Load a save file. Returns an error, if not successfull. */


/** Source file positions. */
export type source =
  { dir: string, base: string, file: string, line: number };


/** Log messages categories. */
export enum logkind {
  /** User Error */
  ERROR = 'ERROR';
  /** User Warning */
  WARNING = 'WARNING';
  /** Plugin Feedback */
  FEEDBACK = 'FEEDBACK';
  /** Plugin Result */
  RESULT = 'RESULT';
  /** Plugin Failure */
  FAILURE = 'FAILURE';
  /** Analyser Debug */
  DEBUG = 'DEBUG';
}


/** Returns all registered tags for the above type. */


/** Message event record. */
export interface log {
  /** Message kind */
  kind: logkind;
  /** Emitter plugin */
  plugin: string;
  /** Message text */
  message: string;
  /** Message category (DEBUG or WARNING) */
  category?: string;
  /** Source file position */
  source?: source;
}


/** Turn logs monitoring on/off */


/** Flush the last emitted logs since last call (max 100) */
