/* --- Generated Frama-C Server API --- */

/** Project Management
   @packageDocumentation
   @module frama-c/kernel/project
*/

import * as Json from 'dome/data/json';
import * as Server from 'frama-c/server';


/** Project informations */
export type projectInfo =
  { id: Json.Key<'project'>, name: string, current: boolean };


/** Request to be executed on the specified project. */
export type projectRequest =
  { project: Json.Key<'project'>, request: string, data: Json.json };


/** Returns the current project */
export const getCurrent: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.project.getCurrent',
};


/** Switches the current project */
export const setCurrent: Server.SetRequest = {
  kind: Server.RqKind.SET,
  name: 'kernel.project.setCurrent',
};


/** Returns the list of all projects */
export const getList: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.project.getList',
};


/** Execute a GET request within the given project */
export const getOn: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'kernel.project.getOn',
};


/** Execute a SET request within the given project */
export const setOn: Server.SetRequest = {
  kind: Server.RqKind.SET,
  name: 'kernel.project.setOn',
};


/** Execute an EXEC request within the given project */
export const execOn: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'kernel.project.execOn',
};


/** Create a new project */
export const create: Server.SetRequest = {
  kind: Server.RqKind.SET,
  name: 'kernel.project.create',
};
