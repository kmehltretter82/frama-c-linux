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
   Kernel Services
   @packageDocumentation
   @module frama-c/kernel/api/services
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
import { byDecl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { byMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { bySource } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { decl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { declDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jDecl } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jMarker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { jSource } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { marker } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { markerDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { source } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { sourceDefault } from 'frama-c/kernel/api/ast';
//@ts-ignore
import { byTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { jTag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tag } from 'frama-c/kernel/api/data';
//@ts-ignore
import { tagDefault } from 'frama-c/kernel/api/data';

const getConfig_internal: Server.GetRequest<
  null,
  { version: string, datadir: string[], pluginpath: string[] }
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.getConfig',
  input: Json.jNull,
  output: Json.jObject({
            version: Json.jString,
            datadir: Json.jArray(Json.jString),
            pluginpath: Json.jArray(Json.jString),
          }),
  signals: [],
};
/** Frama-C Kernel configuration */
export const getConfig: Server.GetRequest<
  null,
  { version: string, datadir: string[], pluginpath: string[] }
  >= getConfig_internal;

const load_internal: Server.SetRequest<string,string | undefined> = {
  kind: Server.RqKind.SET,
  name: 'kernel.services.load',
  input: Json.jString,
  output: Json.jOption(Json.jString),
  signals: [],
};
/** Load a save file. Returns an error, if not successfull. */
export const load: Server.SetRequest<string,string | undefined>= load_internal;

const save_internal: Server.SetRequest<string,string | undefined> = {
  kind: Server.RqKind.SET,
  name: 'kernel.services.save',
  input: Json.jString,
  output: Json.jOption(Json.jString),
  signals: [],
};
/** Save the current session. Returns an error, if not successfull. */
export const save: Server.SetRequest<string,string | undefined>= save_internal;

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

/** Decoder for `logkind` */
export const jLogkind: Json.Decoder<logkind> = Json.jEnum(logkind);

/** Natural order for `logkind` */
export const byLogkind: Compare.Order<logkind> = Compare.byEnum(logkind);

/** Default value for `logkind` */
export const logkindDefault: logkind = logkind.ERROR;

const logkindTags_internal: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.logkindTags',
  input: Json.jNull,
  output: Json.jArray(jTag),
  signals: [],
};
/** Registered tags for the above type. */
export const logkindTags: Server.GetRequest<null,tag[]>= logkindTags_internal;

/** Data for array rows [`message`](#message)  */
export interface messageData {
  /** Entry identifier. */
  key: Json.key<'#message'>;
  /** Message kind */
  kind: logkind;
  /** Emitter plugin */
  plugin: string;
  /** Message text */
  message: string;
  /** Message category (only for debug or warning messages) */
  category?: string;
  /** Source file position */
  source?: source;
  /** Marker at the message position (if any) */
  marker?: marker;
  /** Declaration containing the message position (if any) */
  decl?: decl;
}

/** Decoder for `messageData` */
export const jMessageData: Json.Decoder<messageData> =
  Json.jObject({
    key: Json.jKey<'#message'>('#message'),
    kind: jLogkind,
    plugin: Json.jString,
    message: Json.jString,
    category: Json.jOption(Json.jString),
    source: Json.jOption(jSource),
    marker: Json.jOption(jMarker),
    decl: Json.jOption(jDecl),
  });

/** Natural order for `messageData` */
export const byMessageData: Compare.Order<messageData> =
  Compare.byFields
    <{ key: Json.key<'#message'>, kind: logkind, plugin: string,
       message: string, category?: string, source?: source, marker?: marker,
       decl?: decl }>({
    key: Compare.string,
    kind: byLogkind,
    plugin: Compare.alpha,
    message: Compare.string,
    category: Compare.defined(Compare.string),
    source: Compare.defined(bySource),
    marker: Compare.defined(byMarker),
    decl: Compare.defined(byDecl),
  });

/** Signal for array [`message`](#message)  */
export const signalMessage: Server.Signal = {
  name: 'kernel.services.signalMessage',
};

const reloadMessage_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.reloadMessage',
  input: Json.jNull,
  output: Json.jNull,
  signals: [],
};
/** Force full reload for array [`message`](#message)  */
export const reloadMessage: Server.GetRequest<null,null>= reloadMessage_internal;

const fetchMessage_internal: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#message'>[], updated: messageData[],
    pending: number }
  > = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.fetchMessage',
  input: Json.jNumber,
  output: Json.jObject({
            reload: Json.jBoolean,
            removed: Json.jArray(Json.jKey<'#message'>('#message')),
            updated: Json.jArray(jMessageData),
            pending: Json.jNumber,
          }),
  signals: [],
};
/** Data fetcher for array [`message`](#message)  */
export const fetchMessage: Server.GetRequest<
  number,
  { reload: boolean, removed: Json.key<'#message'>[], updated: messageData[],
    pending: number }
  >= fetchMessage_internal;

const message_internal: State.Array<Json.key<'#message'>,messageData> = {
  name: 'kernel.services.message',
  getkey: ((d:messageData) => d.key),
  signal: signalMessage,
  fetch: fetchMessage,
  reload: reloadMessage,
  order: byMessageData,
};
/** Log messages */
export const message: State.Array<Json.key<'#message'>,messageData> = message_internal;

/** Default value for `messageData` */
export const messageDataDefault: messageData =
  { key: Json.jKey<'#message'>('#message')(''), kind: logkindDefault,
    plugin: '', message: '', category: undefined, source: undefined,
    marker: undefined, decl: undefined };

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

/** Decoder for `log` */
export const jLog: Json.Decoder<log> =
  Json.jObject({
    kind: jLogkind,
    plugin: Json.jString,
    message: Json.jString,
    category: Json.jOption(Json.jString),
    source: Json.jOption(jSource),
  });

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

/** Default value for `log` */
export const logDefault: log =
  { kind: logkindDefault, plugin: '', message: '', category: undefined,
    source: undefined };

const setLogs_internal: Server.SetRequest<boolean,null> = {
  kind: Server.RqKind.SET,
  name: 'kernel.services.setLogs',
  input: Json.jBoolean,
  output: Json.jNull,
  signals: [],
};
/** Turn logs monitoring on/off */
export const setLogs: Server.SetRequest<boolean,null>= setLogs_internal;

const getLogs_internal: Server.GetRequest<null,log[]> = {
  kind: Server.RqKind.GET,
  name: 'kernel.services.getLogs',
  input: Json.jNull,
  output: Json.jArray(jLog),
  signals: [],
};
/** Flush the last emitted logs since last call (max 100) */
export const getLogs: Server.GetRequest<null,log[]>= getLogs_internal;

/* ------------------------------------- */
