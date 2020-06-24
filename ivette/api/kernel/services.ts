/* --- Generated Frama-C Server API --- */

/**
   Kernel Services
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

/** Safe decoder for `source` */
export const jSourceSafe: Json.Safe<source> =
  Json.jObject({
    dir: Json.jFail(Json.jString,'String expected'),
    base: Json.jFail(Json.jString,'String expected'),
    file: Json.jFail(Json.jString,'String expected'),
    line: Json.jFail(Json.jNumber,'Number expected'),
  });

/** Loose decoder for `source` */
export const jSource: Json.Loose<source> = Json.jTry(jSourceSafe);

/** Natural order for `source` */

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

/** Safe decoder for `logkind` */
export const jLogkindSafe: Json.Safe<logkind> =
  Json.jFail(Json.jEnum(logkind),'kernel.services.logkind expected');

/** Loose decoder for `logkind` */
export const jLogkind: Json.Loose<logkind> = Json.jEnum(logkind);

/** Natural order for `logkind` */

/** Registered tags for the above type. */
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

/** Safe decoder for `log` */
export const jLogSafe: Json.Safe<log> =
  Json.jObject({
    kind: Json.jFail(Json.jEnum(logkind),'kernel.services.logkind expected'),
    plugin: Json.jFail(Json.jString,'String expected'),
    message: Json.jFail(Json.jString,'String expected'),
    category: Json.jString,
    source: jSource,
  });

/** Loose decoder for `log` */
export const jLog: Json.Loose<log> = Json.jTry(jLogSafe);

/** Natural order for `log` */

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

/* ------------------------------------- */
