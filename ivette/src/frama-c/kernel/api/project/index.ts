/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

/* --- Generated Frama-C Server API --- */

/**
   Project Management
   @packageDocumentation
   @module frama-c/kernel/api/project
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

/** Decoder for `projectInfo` */
export const jProjectInfo: Json.Decoder<projectInfo> =
  Json.jObject({
    id: Json.jKey<'#project'>('#project'),
    name: Json.jString,
    current: Json.jBoolean,
  });

/** Natural order for `projectInfo` */
export const byProjectInfo: Compare.Order<projectInfo> =
  Compare.byFields
    <{ id: Json.key<'#project'>, name: string, current: boolean }>({
    id: Compare.string,
    name: Compare.alpha,
    current: Compare.boolean,
  });

/** Default value for `projectInfo` */
export const projectInfoDefault: projectInfo =
  { id: Json.jKey<'#project'>('#project')(''), name: '', current: false };

const getList_internal: Server.GetRequest<null,projectInfo[]> = {
  kind: Server.RqKind.GET,
  name: 'kernel.project.getList',
  input: Json.jNull,
  output: Json.jArray(jProjectInfo),
  signals: [],
};
/** Returns the list of all projects */
export const getList: Server.GetRequest<null,projectInfo[]>= getList_internal;

const create_internal: Server.SetRequest<string,projectInfo> = {
  kind: Server.RqKind.SET,
  name: 'kernel.project.create',
  input: Json.jString,
  output: jProjectInfo,
  signals: [],
};
/** Create a new project */
export const create: Server.SetRequest<string,projectInfo>= create_internal;

/* ------------------------------------- */
