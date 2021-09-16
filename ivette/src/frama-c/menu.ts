/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

/* --------------------------------------------------------------------------*/
/* --- Frama-C MENU                                                       ---*/
/* --------------------------------------------------------------------------*/

import * as Dome from 'dome';
import * as Dialogs from 'dome/dialogs';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/api/kernel/ast';
import * as States from 'frama-c/states';

const cFilter = {
  name: 'C source files',
  extensions: ['c', 'i', 'h'],
};
const allFilter = {
  name: 'all',
  extensions: ['*'],
};

async function setFiles(): Promise<void> {
  const files = await Dialogs.showOpenFiles({
    title: 'Select C source files',
    filters: [cFilter, allFilter],
  });
  await Server.send(Ast.setFiles, files);
  await Server.send(Ast.compute, { });
  const main = await Server.send(Ast.getMainFunction, { });
  States.setSelection({ fct: main });
  return;
}

export function init() {
  Dome.addMenuItem({
    menu: 'File',
    label: 'Set source files',
    id: 'file_add',
    onClick: setFiles,
    type: 'normal',
  });
}

/* --------------------------------------------------------------------------*/
