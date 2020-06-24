/* --- Generated Frama-C Server API --- */

/**
   Informations
   @packageDocumentation
   @module frama-c/kernel/data
*/

import * as Json from 'dome/data/json';
import * as Compare from 'dome/data/compare';
import * as Server from 'frama-c/server';
import * as State from 'frama-c/states';


/** Markdown (inlined) text. */
export type markdown = string;

/** Safe decoder for `markdown` */
export const jMarkdownSafe: Json.Safe<markdown> =
  Json.jFail(Json.jString,'String expected');

/** Loose decoder for `markdown` */
export const jMarkdown: Json.Loose<markdown> = Json.jString;

/** Natural order for `markdown` */
export const byMarkdown: Compare.Order<markdown> = Compare.primitive;

/** Rich text format uses `[tag; …text ]` to apply the tag `tag` to the enclosed text. Empty tag `""` can also used to simply group text together. */
export type text = null | string | text[];

/** Safe decoder for `text` */
export const jTextSafe: Json.Safe<text> = Json.jFail(jText,'Text expected');

/** Loose decoder for `text` */
export const jText: Json.Loose<text> =
  Json.jUnion<null | string | text[]>(
    Json.jNull,
    Json.jString,
    Json.jList(jText),
  );

/** Natural order for `text` */
export const byText: Compare.Order<text> = Compare.structural;

/** Enum Tag Description */
export type tag = { name: string, label: markdown, descr: markdown };

/** Safe decoder for `tag` */
export const jTagSafe: Json.Safe<tag> =
  Json.jObject({
    name: Json.jFail(Json.jString,'String expected'),
    label: jMarkdownSafe,
    descr: jMarkdownSafe,
  });

/** Loose decoder for `tag` */
export const jTag: Json.Loose<tag> = Json.jTry(jTagSafe);

/** Natural order for `tag` */
export const byTag: Compare.Order<tag> =
  Compare.byFields({
    name: Compare.primitive,
    label: byMarkdown,
    descr: byMarkdown,
  });

/* ------------------------------------- */
