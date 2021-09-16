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

async function setFiles(): Promise<void> {
  const files = await Dialogs.showOpenFiles({ title: 'Open files' });
  await Server.send(Ast.setFiles, files);
  await Server.send(Ast.compute, { });
  return;
}

export function init() {
  Dome.addMenuItem({
    menu: 'File',
    label: 'Set files',
    id: 'file_add',
    onClick: setFiles,
    type: 'normal',
  });
}

/* --------------------------------------------------------------------------*/
