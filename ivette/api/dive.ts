/* --- Generated Frama-C Server API --- */

/**
   Dive Services
   @packageDocumentation
   @module frama-c/dive
*/

import * as Json from 'dome/data/json';
import * as Server from 'frama-c/server';


/** The name of variable of the program */
export interface variableName {
  /** owner function for a local variable */
  funName?: string;
  /** variable name */
  varName: string;
}

/** Safe decoder for `variableName` */
export const jVariableNameSafe: Json.Safe<variableName> =
  Json.jObject({
    funName: Json.jString,
    varName: Json.jFail(Json.jString,'String expected'),
  });

/** Loose decoder for `variableName` */
export const jVariableName: Json.Loose<variableName> =
  Json.jTry(jVariableNameSafe);

/** Natural order for `variableName` */

/** Retrieve the whole graph */
export const graph: Server.GetRequest = {
  kind: Server.RqKind.GET,
  name: 'dive.graph',
};

/** Erase the graph and start over with an empty one */
export const clear: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'dive.clear',
};

/** Add a variable to the graph */
export const addVar: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'dive.addVar',
};

/** Add all alarms of the given function */
export const addFunctionAlarms: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'dive.addFunctionAlarms',
};

/** Explore the graph starting from an existing vertex */
export const explore: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'dive.explore',
};

/** Show the dependencies of an existing vertex */
export const show: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'dive.show',
};

/** Hide the dependencies of an existing vertex */
export const hide: Server.ExecRequest = {
  kind: Server.RqKind.EXEC,
  name: 'dive.hide',
};

/* ------------------------------------- */
