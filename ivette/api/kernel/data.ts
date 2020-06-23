/* --- Generated Frama-C Server API --- */
/** Informations
   @packageDocumentation
   @module frama-c/kernel/data
*/
import * as Json from 'dome/data/json'
import { markdown } from 'api/kernel/data';
import { tag } from 'api/kernel/data';
import { text } from 'api/kernel/data';


/** Markdown (inlined) text. */
type markdown = string;


/** Rich text format uses `[tag; …text ]` to apply the tag `tag` to the enclosed text. Empty tag `""` can also used to simply group text together. */
type text = null | string | text[];


/** Enum Tag Description */
type tag = { name: string, label: markdown, descr: markdown };
