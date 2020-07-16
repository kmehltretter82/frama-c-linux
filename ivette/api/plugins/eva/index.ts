/* --- Generated Frama-C Server API --- */

/**
   Eva General Services
   @packageDocumentation
   @module api/plugins/eva
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';


const getCallers_internal: Server.GetRequest<
  Json.key<'#fct'>,
  [ Json.key<'#fct'>, Json.key<'#stmt'> ][]
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.getCallers',
  input:  Json.jKey<'#fct'>('#fct'),
  output: Json.jList(Json.jTry(
                       Json.jPair(
                         Json.jFail(Json.jKey<'#fct'>('#fct'),
                           '#fct expected'),
                         Json.jFail(Json.jKey<'#stmt'>('#stmt'),
                           '#stmt expected'),
                       ))),
};
/** Get the list of call site of a function */
export const getCallers: Server.GetRequest<
  Json.key<'#fct'>,
  [ Json.key<'#fct'>, Json.key<'#stmt'> ][]
  >= getCallers_internal;

/* ------------------------------------- */
