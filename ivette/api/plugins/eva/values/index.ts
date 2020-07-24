/* --- Generated Frama-C Server API --- */

/**
   Eva Values
   @packageDocumentation
   @module api/plugins/eva/values
*/

//@ts-ignore
import * as Json from 'dome/data/json';
//@ts-ignore
import * as Compare from 'dome/data/compare';
//@ts-ignore
import * as Server from 'frama-c/server';
//@ts-ignore
import * as State from 'frama-c/states';

//@ts-ignore
import { byMarker } from 'api/kernel/ast';
//@ts-ignore
import { jMarker } from 'api/kernel/ast';
//@ts-ignore
import { jMarkerSafe } from 'api/kernel/ast';
//@ts-ignore
import { marker } from 'api/kernel/ast';

/** CallStack */
export interface callstack {
  /** Callstack id */
  id: number;
  /** Short name for the callstack */
  short: string;
  /** Full name for the callstack */
  full: string;
}

/** Loose decoder for `callstack` */
export const jCallstack: Json.Loose<callstack> =
  Json.jObject({
    id: Json.jFail(Json.jNumber,'Number expected'),
    short: Json.jFail(Json.jString,'String expected'),
    full: Json.jFail(Json.jString,'String expected'),
  });

/** Safe decoder for `callstack` */
export const jCallstackSafe: Json.Safe<callstack> =
  Json.jFail(jCallstack,'Callstack expected');

/** Natural order for `callstack` */
export const byCallstack: Compare.Order<callstack> =
  Compare.byFields
    <{ id: number, short: string, full: string }>({
    id: Compare.number,
    short: Compare.string,
    full: Compare.string,
  });

/** Data for array rows [`values`](#values)  */
export interface valuesData {
  /** Entry identifier. */
  key: Json.key<'#values'>;
  /** CallStack */
  callstack: callstack;
  /** Value inferred just before the selected point */
  value_before: string;
  /** Did the evaluation led to an alarm? */
  alarm: boolean;
  /** Value inferred just after the selected point */
  value_after?: string;
}

/** Loose decoder for `valuesData` */
export const jValuesData: Json.Loose<valuesData> =
  Json.jObject({
    key: Json.jFail(Json.jKey<'#values'>('#values'),'#values expected'),
    callstack: jCallstackSafe,
    value_before: Json.jFail(Json.jString,'String expected'),
    alarm: Json.jFail(Json.jBoolean,'Boolean expected'),
    value_after: Json.jString,
  });

/** Safe decoder for `valuesData` */
export const jValuesDataSafe: Json.Safe<valuesData> =
  Json.jFail(jValuesData,'ValuesData expected');

/** Natural order for `valuesData` */
export const byValuesData: Compare.Order<valuesData> =
  Compare.byFields
    <{ key: Json.key<'#values'>, callstack: callstack, value_before: string,
       alarm: boolean, value_after?: string }>({
    key: Compare.string,
    callstack: byCallstack,
    value_before: Compare.string,
    alarm: Compare.boolean,
    value_after: Compare.defined(Compare.string),
  });

/** Signal for array [`values`](#values)  */
export const signalValues: Server.Signal = {
  name: 'plugins.eva.values.signalValues',
};

const reloadValues_internal: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.reloadValues',
  input:  Json.jNull,
  output: Json.jNull,
};
/** Force full reload for array [`values`](#values)  */
export const reloadValues: Server.GetRequest<null,null>= reloadValues_internal;

const fetchValues_internal: Server.GetRequest<
  number,
  { pending: number, updated: valuesData[], removed: Json.key<'#values'>[],
    reload: boolean }
  > = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.fetchValues',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jFail(Json.jNumber,'Number expected'),
            updated: Json.jList(jValuesData),
            removed: Json.jList(Json.jKey<'#values'>('#values')),
            reload: Json.jFail(Json.jBoolean,'Boolean expected'),
          }),
};
/** Data fetcher for array [`values`](#values)  */
export const fetchValues: Server.GetRequest<
  number,
  { pending: number, updated: valuesData[], removed: Json.key<'#values'>[],
    reload: boolean }
  >= fetchValues_internal;

const values_internal: State.Array<Json.key<'#values'>,valuesData> = {
  name: 'plugins.eva.values.values',
  getkey: ((d:valuesData) => d.key),
  signal: signalValues,
  fetch: fetchValues,
  reload: reloadValues,
  order: byValuesData,
};
/** Abstract values inferred by the Eva analysis */
export const values: State.Array<Json.key<'#values'>,valuesData> = values_internal;

const getValues_internal: Server.GetRequest<marker,null> = {
  kind: Server.RqKind.GET,
  name:   'plugins.eva.values.getValues',
  input:  jMarker,
  output: Json.jNull,
};
/** Get the abstract values computed for an expression or lvalue */
export const getValues: Server.GetRequest<marker,null>= getValues_internal;

/* ------------------------------------- */
