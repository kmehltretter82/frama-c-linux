/* --- Generated Frama-C Server API --- */

/** Kernel Services
   @packageDocumentation
   @module frama-c/kernel/services
*/

import * as Json from 'dome/data/json';
import * as Server from 'frama-c/server';
import { tag } from 'api/kernel/data';


/** Frama-C Kernel configuration */
export const getConfig: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.getConfig',
};


/** Load a save file. Returns an error, if not successfull. */
export const load: Server.SetRequest = {
  kind: Server.RqKind.SET,
  name: 'kernel.services.load',
};


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
export const logkindTags: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.logkindTags',
};


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
export const setLogs: Server.SetRequest = {
  kind: Server.RqKind.SET,
  name: 'kernel.services.setLogs',
};


/** Flush the last emitted logs since last call (max 100) */
export const getLogs: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.getLogs',
};
