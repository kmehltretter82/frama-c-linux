/* --- Generated Frama-C Server API --- */
/** Ast Services
   @packageDocumentation
   @module frama-c/kernel/ast
*/
import * as Json from 'dome/data/json'
import { compute } from 'api/kernel/ast';
import { functions } from 'api/kernel/ast';
import { functionsFetch } from 'api/kernel/ast';
import { functionsReload } from 'api/kernel/ast';
import { functionsRow } from 'api/kernel/ast';
import { functionsSig } from 'api/kernel/ast';
import { getFiles } from 'api/kernel/ast';
import { getFunctions } from 'api/kernel/ast';
import { getInfo } from 'api/kernel/ast';
import { marker } from 'api/kernel/ast';
import { markerData } from 'api/kernel/ast';
import { markerDataFetch } from 'api/kernel/ast';
import { markerDataReload } from 'api/kernel/ast';
import { markerDataRow } from 'api/kernel/ast';
import { markerDataSig } from 'api/kernel/ast';
import { markerKind } from 'api/kernel/ast';
import { markerKindTags } from 'api/kernel/ast';
import { printFunction } from 'api/kernel/ast';
import { setFiles } from 'api/kernel/ast';
import { tag } from 'api/kernel/data';
import { text } from 'api/kernel/data';


/** Ensures that AST is computed */


/** Marker kind */


/** Returns all registered tags for the above type. */


/** Markers data */


/** Signal for array [`markerData`](#markerdata)  */


/** Data rows for array [`markerData`](#markerdata)
 */


/** Data fetcher for array [`markerData`](#markerdata)
 */


/** Force full reload for array [`markerData`](#markerdata)
 */


/** Localizable AST markers */
type marker = Json.Key<'stmt'> | Json.Key<'decl'> | Json.Key<'lval'>
                | Json.Key<'expr'> | Json.Key<'term'> | Json.Key<'global'>
                | Json.Key<'property'>;


/** Collect all functions in the AST */


/** Print the AST of a function */


/** AST Functions */


/** Signal for array [`functions`](#functions)  */


/** Data rows for array [`functions`](#functions)
 */


/** Data fetcher for array [`functions`](#functions)
 */


/** Force full reload for array [`functions`](#functions)
 */


/** Get textual information about a marker */


/** Get the currently analyzed source file names */


/** Set the source file names to analyze. */
