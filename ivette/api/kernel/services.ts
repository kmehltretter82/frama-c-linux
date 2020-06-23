/* --- Generated Frama-C Server API --- */
/** Kernel Services
   @packageDocumentation
   @module frama-c/kernel/services
*/
import * as Json from 'dome/data/json'
import { tag } from 'api/kernel/data';
import { getConfig } from 'api/kernel/services';
import { getLogs } from 'api/kernel/services';
import { load } from 'api/kernel/services';
import { log } from 'api/kernel/services';
import { logkind } from 'api/kernel/services';
import { logkindTags } from 'api/kernel/services';
import { setLogs } from 'api/kernel/services';
import { source } from 'api/kernel/services';


/** Frama-C Kernel configuration */


/** Load a save file. Returns an error, if not successfull. */


/** Source file positions. */
type source = { dir: string, base: string, file: string, line: number };


/** Log messages categories. */


/** Returns all registered tags for the above type. */


/** Message event record. */


/** Turn logs monitoring on/off */


/** Flush the last emitted logs since last call (max 100) */
