/* --- Generated Frama-C Server API --- */

/** Project Management
   @packageDocumentation
   @module frama-c/kernel/project
*/

import * as Json from 'dome/data/json'


/** Project informations */
export type projectInfo =
  { id: Json.Key<'project'>, name: string, current: boolean };


/** Request to be executed on the specified project. */
export type projectRequest =
  { project: Json.Key<'project'>, request: string, data: Json.json };


/** Returns the current project */


/** Switches the current project */


/** Returns the list of all projects */


/** Execute a GET request within the given project */


/** Execute a SET request within the given project */


/** Execute an EXEC request within the given project */


/** Create a new project */
