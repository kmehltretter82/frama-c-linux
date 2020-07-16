/* --- Generated Frama-C Server API --- */

/**
   Informations
   @packageDocumentation
   @module api/kernel/data
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

/** Loose decoder for `markdown` */
export const jMarkdown: Json.Loose<markdown> = Json.jString;

/** Safe decoder for `markdown` */
export const jMarkdownSafe: Json.Safe<markdown> =
  Json.jFail(Json.jString,'String expected');

/** Natural order for `markdown` */
export const byMarkdown: Compare.Order<markdown> = Compare.string;

/** Rich text format uses `[tag; …text ]` to apply the tag `tag` to the enclosed text. Empty tag `""` can also used to simply group text together. */
export type text = null | string | text[];

/** Loose decoder for `text` */
export const jText: Json.Loose<text> =
  (_x: any) => Json.jUnion<null | string | text[]>(
                 Json.jNull,
                 Json.jString,
                 Json.jList(jText),
               )(_x);

/** Safe decoder for `text` */
export const jTextSafe: Json.Safe<text> =
  (_x: any) => Json.jFail(jText,'Text expected')(_x);

/** Natural order for `text` */
export const byText: Compare.Order<text> =
  (_x: any, _y: any) => Compare.structural(_x,_y);

/** Enum Tag Description */
export type tag = { name: string, label: markdown, descr: markdown };

/** Loose decoder for `tag` */
export const jTag: Json.Loose<tag> =
  Json.jObject({
    name: Json.jFail(Json.jString,'String expected'),
    label: jMarkdownSafe,
    descr: jMarkdownSafe,
  });

/** Safe decoder for `tag` */
export const jTagSafe: Json.Safe<tag> = Json.jFail(jTag,'Tag expected');

/** Natural order for `tag` */
export const byTag: Compare.Order<tag> =
  Compare.byFields
    <{ name: string, label: markdown, descr: markdown }>({
    name: Compare.alpha,
    label: byMarkdown,
    descr: byMarkdown,
  });

/* ------------------------------------- */
