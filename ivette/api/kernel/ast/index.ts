/* --- Generated Frama-C Server API --- */

/**
   Ast Services
   @packageDocumentation
   @module frama-c/kernel/ast
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
import { byTag } from 'api/kernel/data';
//@ts-ignore
import { byText } from 'api/kernel/data';
//@ts-ignore
import { jTag } from 'api/kernel/data';
//@ts-ignore
import { jTagSafe } from 'api/kernel/data';
//@ts-ignore
import { jText } from 'api/kernel/data';
//@ts-ignore
import { jTextSafe } from 'api/kernel/data';
//@ts-ignore
import { tag } from 'api/kernel/data';
//@ts-ignore
import { text } from 'api/kernel/data';

/** Ensures that AST is computed */
export const compute: Server.ExecRequest<null,null> = {
  kind: Server.RqKind.EXEC,
  name:   'kernel.ast.compute',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Marker kind */
export enum markerKind {
  /** Expression */
  expression = 'expression',
  /** Lvalue */
  lvalue = 'lvalue',
  /** Variable */
  variable = 'variable',
  /** Function */
  function = 'function',
  /** Declaration */
  declaration = 'declaration',
  /** Statement */
  statement = 'statement',
  /** Global */
  global = 'global',
  /** Term */
  term = 'term',
  /** Property */
  property = 'property',
}

/** Loose decoder for `markerKind` */
export const jMarkerKind: Json.Loose<markerKind> = Json.jEnum(markerKind);

/** Safe decoder for `markerKind` */
export const jMarkerKindSafe: Json.Safe<markerKind> =
  Json.jFail(Json.jEnum(markerKind),'kernel.ast.markerKind expected');

/** Natural order for `markerKind` */
export const byMarkerKind: Compare.Order<markerKind> =
  Compare.byEnum(markerKind);

/** Registered tags for the above type. */
export const markerKindTags: Server.GetRequest<null,tag[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.markerKindTags',
  input:  Json.jNull,
  output: Json.jList(jTag),
};

/** Data for array rows [`markerInfo`](#markerinfo)  */
export interface markerInfoData {
  /** Entry identifier. */
  key: Json.key<'#markerInfo'>;
  /** Marker kind */
  kind: markerKind;
  /** Marker short name */
  name: string;
  /** Marker declaration or description */
  descr: string;
}

/** Loose decoder for `markerInfoData` */
export const jMarkerInfoData: Json.Loose<markerInfoData> =
  Json.jObject({
    key: Json.jFail(Json.jKey<'#markerInfo'>('#markerInfo'),
           '#markerInfo expected'),
    kind: jMarkerKindSafe,
    name: Json.jFail(Json.jString,'String expected'),
    descr: Json.jFail(Json.jString,'String expected'),
  });

/** Safe decoder for `markerInfoData` */
export const jMarkerInfoDataSafe: Json.Safe<markerInfoData> =
  Json.jFail(jMarkerInfoData,'MarkerInfoData expected');

/** Natural order for `markerInfoData` */
export const byMarkerInfoData: Compare.Order<markerInfoData> =
  Compare.byFields
    <{ key: Json.key<'#markerInfo'>, kind: markerKind, name: string,
       descr: string }>({
    key: Compare.primitive,
    kind: byMarkerKind,
    name: Compare.alpha,
    descr: Compare.primitive,
  });

/** Signal for array [`markerInfo`](#markerinfo)  */
export const signalMarkerInfo: Server.Signal = {
  name: 'kernel.ast.signalMarkerInfo',
};

/** Force full reload for array [`markerInfo`](#markerinfo)  */
export const reloadMarkerInfo: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadMarkerInfo',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Data fetcher for array [`markerInfo`](#markerinfo)  */
export const fetchMarkerInfo: Server.GetRequest<number,
  { pending: number, updated: markerInfoData[],
    removed: Json.key<'#markerInfo'>[], reload: boolean }> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchMarkerInfo',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jFail(Json.jNumber,'Number expected'),
            updated: Json.jList(jMarkerInfoData),
            removed: Json.jList(Json.jKey<'#markerInfo'>('#markerInfo')),
            reload: Json.jFail(Json.jBoolean,'Boolean expected'),
          }),
};

/** Marker informations */
export const markerInfo: State.Array<'#markerInfo',markerInfoData> = {
  name: 'kernel.ast.markerInfo',
  key: 'key',
  signal: signalMarkerInfo,
  fetch: fetchMarkerInfo,
  reload: reloadMarkerInfo,
};

/** Localizable AST markers */
export type marker =
  Json.key<'#stmt'> | Json.key<'#decl'> | Json.key<'#lval'> |
  Json.key<'#expr'> | Json.key<'#term'> | Json.key<'#global'> |
  Json.key<'#property'>;

/** Loose decoder for `marker` */
export const jMarker: Json.Loose<marker> =
  Json.jUnion<Json.key<'#stmt'> | Json.key<'#decl'> | Json.key<'#lval'> |
              Json.key<'#expr'> | Json.key<'#term'> | Json.key<'#global'> |
              Json.key<'#property'>>(
    Json.jKey<'#stmt'>('#stmt'),
    Json.jKey<'#decl'>('#decl'),
    Json.jKey<'#lval'>('#lval'),
    Json.jKey<'#expr'>('#expr'),
    Json.jKey<'#term'>('#term'),
    Json.jKey<'#global'>('#global'),
    Json.jKey<'#property'>('#property'),
  );

/** Safe decoder for `marker` */
export const jMarkerSafe: Json.Safe<marker> =
  Json.jFail(jMarker,'Marker expected');

/** Natural order for `marker` */
export const byMarker: Compare.Order<marker> = Compare.structural;

/** Collect all functions in the AST */
export const getFunctions: Server.GetRequest<null,Json.key<'#fct'>[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFunctions',
  input:  Json.jNull,
  output: Json.jList(Json.jKey<'#fct'>('#fct')),
};

/** Print the AST of a function */
export const printFunction: Server.GetRequest<Json.key<'#fct'>,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.printFunction',
  input:  Json.jKey<'#fct'>('#fct'),
  output: jText,
};

/** Data for array rows [`functions`](#functions)  */
export interface functionsData {
  /** Entry identifier. */
  key: Json.key<'#functions'>;
  /** Name */
  name: string;
  /** Signature */
  signature: string;
}

/** Loose decoder for `functionsData` */
export const jFunctionsData: Json.Loose<functionsData> =
  Json.jObject({
    key: Json.jFail(Json.jKey<'#functions'>('#functions'),
           '#functions expected'),
    name: Json.jFail(Json.jString,'String expected'),
    signature: Json.jFail(Json.jString,'String expected'),
  });

/** Safe decoder for `functionsData` */
export const jFunctionsDataSafe: Json.Safe<functionsData> =
  Json.jFail(jFunctionsData,'FunctionsData expected');

/** Natural order for `functionsData` */
export const byFunctionsData: Compare.Order<functionsData> =
  Compare.byFields
    <{ key: Json.key<'#functions'>, name: string, signature: string }>({
    key: Compare.primitive,
    name: Compare.alpha,
    signature: Compare.primitive,
  });

/** Signal for array [`functions`](#functions)  */
export const signalFunctions: Server.Signal = {
  name: 'kernel.ast.signalFunctions',
};

/** Force full reload for array [`functions`](#functions)  */
export const reloadFunctions: Server.GetRequest<null,null> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.reloadFunctions',
  input:  Json.jNull,
  output: Json.jNull,
};

/** Data fetcher for array [`functions`](#functions)  */
export const fetchFunctions: Server.GetRequest<number,
  { pending: number, updated: functionsData[],
    removed: Json.key<'#functions'>[], reload: boolean }> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.fetchFunctions',
  input:  Json.jNumber,
  output: Json.jObject({
            pending: Json.jFail(Json.jNumber,'Number expected'),
            updated: Json.jList(jFunctionsData),
            removed: Json.jList(Json.jKey<'#functions'>('#functions')),
            reload: Json.jFail(Json.jBoolean,'Boolean expected'),
          }),
};

/** AST Functions */
export const functions: State.Array<'#functions',functionsData> = {
  name: 'kernel.ast.functions',
  key: 'key',
  signal: signalFunctions,
  fetch: fetchFunctions,
  reload: reloadFunctions,
};

/** Get textual information about a marker */
export const getInfo: Server.GetRequest<marker,text> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getInfo',
  input:  jMarker,
  output: jText,
};

/** Get the currently analyzed source file names */
export const getFiles: Server.GetRequest<null,string[]> = {
  kind: Server.RqKind.GET,
  name:   'kernel.ast.getFiles',
  input:  Json.jNull,
  output: Json.jList(Json.jString),
};

/** Set the source file names to analyze. */
export const setFiles: Server.SetRequest<string[],null> = {
  kind: Server.RqKind.SET,
  name:   'kernel.ast.setFiles',
  input:  Json.jList(Json.jString),
  output: Json.jNull,
};

/* ------------------------------------- */
