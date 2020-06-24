/* --- Generated Frama-C Server API --- */

/**
   Informations
   @packageDocumentation
   @module frama-c/kernel/data
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
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
export const jTextSafe: Json.Safe<text> =
  (_x) => Json.jFail(jText,'Text expected')(_x);

/** Loose decoder for `text` */
export const jText: Json.Loose<text> =
  (_x) => Json.jUnion<null | string | text[]>(
            Json.jNull,
            Json.jString,
            Json.jList(jText),
          )(_x);

/** Natural order for `text` */
export const byText: Compare.Order<text> =
  (_x,_y) => Compare.structural(_x,_y);

/** Enum Tag Description */
export type tag = { name: string, label: markdown, descr: markdown };

/** Safe decoder for `tag` */
export const jTagSafe: Json.Safe<tag> = Json.jFail(jTag,'Tag expected');

/** Loose decoder for `tag` */
export const jTag: Json.Loose<tag> =
  Json.jObject({
    name: Json.jFail(Json.jString,'String expected'),
    label: jMarkdownSafe,
    descr: jMarkdownSafe,
  });

/** Natural order for `tag` */
export const byTag: Compare.Order<tag> =
  Compare.byFields
    <{ name: string, label: markdown, descr: markdown }>({
    name: Compare.alpha,
    label: byMarkdown,
    descr: byMarkdown,
  });

/* ------------------------------------- */
