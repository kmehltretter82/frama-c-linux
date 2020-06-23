/* --- Generated Frama-C Server API --- */
/** Project Management
   @packageDocumentation
   @module frama-c/kernel/project
*/
import * as Json from 'dome/data/json'
import { create } from 'api/kernel/project';
import { execOn } from 'api/kernel/project';
import { getCurrent } from 'api/kernel/project';
import { getList } from 'api/kernel/project';
import { getOn } from 'api/kernel/project';
import { projectInfo } from 'api/kernel/project';
import { projectRequest } from 'api/kernel/project';
import { setCurrent } from 'api/kernel/project';
import { setOn } from 'api/kernel/project';


/** Project informations */
type projectInfo = { id: Json.Key<'project'>, name: string, current: boolean
                     };


/** Request to be executed on the specified project. */
type projectRequest = { project: Json.Key<'project'>, request: string,
                        data: Json.json };


/** Returns the current project */


/** Switches the current project */


/** Returns the list of all projects */


/** Execute a GET request within the given project */


/** Execute a SET request within the given project */


/** Execute an EXEC request within the given project */


/** Create a new project */
