/* --- Generated Frama-C Server API --- */
/** Property Services
   @packageDocumentation
   @module frama-c/kernel/properties
*/
import * as Json from 'dome/data/json'
import { tag } from 'api/kernel/data';
import { alarms } from 'api/kernel/properties';
import { alarmsTags } from 'api/kernel/properties';
import { propKind } from 'api/kernel/properties';
import { propKindTags } from 'api/kernel/properties';
import { propStatus } from 'api/kernel/properties';
import { propStatusTags } from 'api/kernel/properties';
import { status } from 'api/kernel/properties';
import { statusFetch } from 'api/kernel/properties';
import { statusReload } from 'api/kernel/properties';
import { statusRow } from 'api/kernel/properties';
import { statusSig } from 'api/kernel/properties';
import { source } from 'api/kernel/services';


/** Property Kinds */


/** Returns all registered tags for the above type. */


/** Property Status (consolidated) */


/** Returns all registered tags for the above type. */


/** Alarm Kinds */


/** Returns all registered tags for the above type. */


/** Status of Registered Properties */


/** Signal for array [`status`](#status)  */


/** Data rows for array [`status`](#status)  */


/** Data fetcher for array [`status`](#status)
 */


/** Force full reload for array [`status`](#status)
 */
