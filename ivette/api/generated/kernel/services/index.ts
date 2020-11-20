/* --- Generated Frama-C Server API --- */

/**
   Kernel Services
   @packageDocumentation
   @module frama-c/api/kernel/services
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
import { byTag } from 'frama-c/api/kernel/data';
//@ts-ignore
import { jTag } from 'frama-c/api/kernel/data';
//@ts-ignore
import { jTagSafe } from 'frama-c/api/kernel/data';
//@ts-ignore
import { tag } from 'frama-c/api/kernel/data';

const getConfig_internal: Server.GetRequest<
  null,
  { pluginpath: string[], libdir: string, datadir: string, version: string }
  > = {
  kind: Server.RqKind.GET,
  name:   'kernel.services.getConfig',
  input:  Json.jNull,
  output: Json.jObject({
            pluginpath: Json.jList(Json.jString),
            libdir: Json.jFail(Json.jString,'String expected'),
            datadir: Json.jFail(Json.jString,'String expected'),
            version: Json.jFail(Json.jString,'String expected'),
          }),
};
/** Frama-C Kernel configuration */
export const getConfig: Server.GetRequest<
  null,
  { pluginpath: string[], libdir: string, datadir: string, version: string }
  >= getConfig_internal;

const load_internal: Server.SetRequest<string,string | undefined> = {
  kind: Server.RqKind.SET,
  name:   'kernel.services.load',
  input:  Json.jString,
  output: Json.jString,
};
/** Load a save file. Returns an error, if not successfull. */
export const load: Server.SetRequest<string,string | undefined>= load_internal;

/** Source file positions. */
export type source =
  { dir: string, base: string, file: string, line: number };

/** Loose decoder for `source` */
export const jSource: Json.Loose<source> =
  Json.jObject({
    dir: Json.jFail(Json.jString,'String expected'),
    base: Json.jFail(Json.jString,'String expected'),
    file: Json.jFail(Json.jString,'String expected'),
    line: Json.jFail(Json.jNumber,'Number expected'),
  });

/** Safe decoder for `source` */
export const jSourceSafe: Json.Safe<source> =
  Json.jFail(jSource,'Source expected');

/** Natural order for `source` */
export const bySource: Compare.Order<source> =
  Compare.byFields
    <{ dir: string, base: string, file: string, line: number }>({
    dir: Compare.string,
    base: Compare.string,
    file: Compare.string,
    line: Compare.number,
  });

/** Log messages categories. */
export enum logkind {
  /** User Error */
  ERROR = 'ERROR',
  /** User Warning */
  WARNING = 'WARNING',
  /** Plugin Feedback */
  FEEDBACK = 'FEEDBACK',
  /** Plugin Result */
  RESULT = 'RESULT',
  /** Plugin Failure */
  FAILURE = 'FAILURE',
  /** Analyser Debug */
  DEBUG = 'DEBUG',
}

/** Loose decoder for `logkind` */
export const jLogkind: Json.Loose<logkind> = Json.jEnum(logkind);

/** Safe decoder for `logkind` */
export const jLogkindSafe: Json.Safe<logkind> =
  Json.jFail(Json.jEnum(logkind),'kernel.services.logkind expected');

/** Natural order for `logkind` */
export const byLogkind: Compare.Order<logkind> = Compare.byEnum(logkind);

const logkindTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.services.logkindTags',
  input:  Json.jNull,
  output: Json.jList(jTag),
};
/** Registered tags for the above type. */
export const logkindTags: Server.GetRequest<null,tag[]>= logkindTags_internal;

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

/** Loose decoder for `log` */
export const jLog: Json.Loose<log> =
  Json.jObject({
    kind: jLogkindSafe,
    plugin: Json.jFail(Json.jString,'String expected'),
    message: Json.jFail(Json.jString,'String expected'),
    category: Json.jString,
    source: jSource,
  });

/** Safe decoder for `log` */
export const jLogSafe: Json.Safe<log> = Json.jFail(jLog,'Log expected');

/** Natural order for `log` */
export const byLog: Compare.Order<log> =
  Compare.byFields
    <{ kind: logkind, plugin: string, message: string, category?: string,
       source?: source }>({
    kind: byLogkind,
    plugin: Compare.alpha,
    message: Compare.string,
    category: Compare.defined(Compare.string),
    source: Compare.defined(bySource),
  });

const setLogs_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name:   'kernel.services.setLogs',
  input:  Json.jBoolean,
  output: Json.jNull,
};
/** Turn logs monitoring on/off */
export const setLogs: Server.SetRequest<boolean,null>= setLogs_internal;

const getLogs_internal: Server.GetRequest<null,log[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.services.getLogs',
  input:  Json.jNull,
  output: Json.jList(jLog),
};
/** Flush the last emitted logs since last call (max 100) */
export const getLogs: Server.GetRequest<null,log[]>= getLogs_internal;

/* ------------------------------------- */
