/* --- Generated Frama-C Server API --- */

/**
   Project Management
   @packageDocumentation
   @module frama-c/kernel/project
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';


/** Project informations */
export type projectInfo =
  { id: Json.key<'#project'>, name: string, current: boolean };

/** Safe decoder for `projectInfo` */
export const jProjectInfoSafe: Json.Safe<projectInfo> =
  Json.jFail(jProjectInfo,'ProjectInfo expected');

/** Loose decoder for `projectInfo` */
export const jProjectInfo: Json.Loose<projectInfo> =
  Json.jObject({
    id: Json.jFail(Json.jKey('#project'),'#project expected'),
    name: Json.jFail(Json.jString,'String expected'),
    current: Json.jFail(Json.jBoolean,'Boolean expected'),
  });

/** Natural order for `projectInfo` */
export const byProjectInfo: Compare.Order<projectInfo> =
  Compare.byFields
    <{ id: Json.key<'#project'>, name: string, current: boolean }>({
    id: Compare.primitive,
    name: Compare.alpha,
    current: Compare.primitive,
  });

/** Request to be executed on the specified project. */
export type projectRequest =
  { project: Json.key<'#project'>, request: string, data: Json.json };

/** Safe decoder for `projectRequest` */
export const jProjectRequestSafe: Json.Safe<projectRequest> =
  Json.jFail(jProjectRequest,'ProjectRequest expected');

/** Loose decoder for `projectRequest` */
export const jProjectRequest: Json.Loose<projectRequest> =
  Json.jObject({
    project: Json.jFail(Json.jKey('#project'),'#project expected'),
    request: Json.jFail(Json.jString,'String expected'),
    data: Json.jAny,
  });

/** Natural order for `projectRequest` */
export const byProjectRequest: Compare.Order<projectRequest> =
  Compare.byFields
    <{ project: Json.key<'#project'>, request: string, data: Json.json }>({
    project: Compare.primitive,
    request: Compare.primitive,
    data: Compare.structural,
  });

/** Returns the current project */
export const getCurrent: Server.GetRequest<null,projectInfo> = {
  kind: Server.RqKind.GET,
  name:   'kernel.project.getCurrent',
  input:  Json.jNull,
  output: jProjectInfo,
};

/** Switches the current project */
export const setCurrent: Server.SetRequest<Json.key<'#project'>,null> = {
  kind: Server.RqKind.SET,
  name:   'kernel.project.setCurrent',
  input:  Json.jKey('#project'),
  output: Json.jNull,
};

/** Returns the list of all projects */
export const getList: Server.GetRequest<null,projectInfo[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.project.getList',
  input:  Json.jNull,
  output: Json.jList(jProjectInfo),
};

/** Execute a GET request within the given project */
export const getOn: Server.GetRequest<projectRequest,Json.json> = {
  kind: Server.RqKind.GET,
  name:   'kernel.project.getOn',
  input:  jProjectRequest,
  output: Json.jAny,
};

/** Execute a SET request within the given project */
export const setOn: Server.SetRequest<projectRequest,Json.json> = {
  kind: Server.RqKind.SET,
  name:   'kernel.project.setOn',
  input:  jProjectRequest,
  output: Json.jAny,
};

/** Execute an EXEC request within the given project */
export const execOn: Server.ExecRequest<projectRequest,Json.json> = {
  kind: Server.RqKind.EXEC,
  name:   'kernel.project.execOn',
  input:  jProjectRequest,
  output: Json.jAny,
};

/** Create a new project */
export const create: Server.SetRequest<string,projectInfo> = {
  kind: Server.RqKind.SET,
  name:   'kernel.project.create',
  input:  Json.jString,
  output: jProjectInfo,
};

/* ------------------------------------- */
