/* --- Generated Frama-C Server API --- */

/** Informations
   @packageDocumentation
   @module frama-c/kernel/data
*/

import * as Json from 'dome/data/json'


/** Markdown (inlined) text. */
export type markdown = string;


/** Rich text format uses `[tag; …text ]` to apply the tag `tag` to the enclosed text. Empty tag `""` can also used to simply group text together. */
export type text = null | string | text[];


/** Enum Tag Description */
export type tag = { name: string, label: markdown, descr: markdown };
