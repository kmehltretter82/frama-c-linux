/* --- Generated Frama-C Server API --- */

/**
   Project Management
   @packageDocumentation
   @module frama-c/kernel/project
*/

import * as Json from 'dome/data/json';
import * as Server from 'frama-c/server';


/** Project informations */
export type projectInfo =
  { id: Json.Key<'project'>, name: string, current: boolean };

/** Safe decoder for `projectInfo` */
export const jProjectInfoSafe: Json.Safe<projectInfo> =
  Json.jObject({
    id: Json.jFail(Json.jKey('project'),'#project expected'),
    name: Json.jFail(Json.jString,'String expected'),
    current: Json.jFail(Json.jBoolean,'Boolean expected'),
  });

/** Loose decoder for `projectInfo` */
export const jProjectInfo: Json.Loose<projectInfo> =
  Json.jTry(jProjectInfoSafe);

/** Natural order for `projectInfo` */

/** Request to be executed on the specified project. */
export type projectRequest =
  { project: Json.Key<'project'>, request: string, data: Json.json };

/** Safe decoder for `projectRequest` */
export const jProjectRequestSafe: Json.Safe<projectRequest> =
  Json.jObject({
    project: Json.jFail(Json.jKey('project'),'#project expected'),
    request: Json.jFail(Json.jString,'String expected'),
    data: Json.jAny,
  });

/** Loose decoder for `projectRequest` */
export const jProjectRequest: Json.Loose<projectRequest> =
  Json.jTry(jProjectRequestSafe);

/** Natural order for `projectRequest` */

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

/* ------------------------------------- */
