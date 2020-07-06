/* --- Generated Frama-C Server API --- */

/**
   Dive Services
   @packageDocumentation
   @module api/dive
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';


/** The name of variable of the program */
export interface variableName {
  /** owner function for a local variable */
  funName?: string;
  /** variable name */
  varName: string;
}

/** Loose decoder for `variableName` */
export const jVariableName: Json.Loose<variableName> =
  Json.jObject({
    funName: Json.jString,
    varName: Json.jFail(Json.jString,'String expected'),
  });

/** Safe decoder for `variableName` */
export const jVariableNameSafe: Json.Safe<variableName> =
  Json.jFail(jVariableName,'VariableName expected');

/** Natural order for `variableName` */
export const byVariableName: Compare.Order<variableName> =
  Compare.byFields
    <{ funName?: string, varName: string }>({
    funName: Compare.defined(Compare.alpha),
    varName: Compare.alpha,
  });

/** Retrieve the whole graph */
export const graph: Server.GetRequest<null,Json.json> = {
  kind: Server.RqKind.GET,
  name:   'dive.graph',
  input:  Json.jNull,
  output: Json.jAny,
};

/** Erase the graph and start over with an empty one */
export const clear: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name:   'dive.clear',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Add a variable to the graph */
export const addVar: Server.ExecRequest<variableName,Json.json> = {
  kind: Server.RqKind.EXEC,
  name:   'dive.addVar',
  input:  jVariableName,
  output: Json.jAny,
};

/** Add all alarms of the given function */
export const addFunctionAlarms: Server.ExecRequest<
  Json.key<'#fct'>,
  Json.json
  > = {
  kind: Server.RqKind.EXEC,
  name:   'dive.addFunctionAlarms',
  input:  Json.jKey<'#fct'>('#fct'),
  output: Json.jAny,
};

/** Explore the graph starting from an existing vertex */
export const explore: Server.ExecRequest<Json.index<'#dive-node'>,Json.json> = {
  kind: Server.RqKind.EXEC,
  name:   'dive.explore',
  input:  Json.jIndex<'#dive-node'>('#dive-node'),
  output: Json.jAny,
};

/** Show the dependencies of an existing vertex */
export const show: Server.ExecRequest<Json.index<'#dive-node'>,Json.json> = {
  kind: Server.RqKind.EXEC,
  name:   'dive.show',
  input:  Json.jIndex<'#dive-node'>('#dive-node'),
  output: Json.jAny,
};

/** Hide the dependencies of an existing vertex */
export const hide: Server.ExecRequest<Json.index<'#dive-node'>,Json.json> = {
  kind: Server.RqKind.EXEC,
  name:   'dive.hide',
  input:  Json.jIndex<'#dive-node'>('#dive-node'),
  output: Json.jAny,
};

/* ------------------------------------- */
