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

/* --------------------------------------------------------------------------*/
/* --- Frama-C MENU                                                       ---*/
/* --------------------------------------------------------------------------*/

import { ipcRenderer } from 'electron';
import * as Dome from 'dome';
import * as Dialogs from 'dome/dialogs';
import * as Display from 'ivette/display';
import * as Server from 'frama-c/server';
import * as Services from 'frama-c/kernel/api/services';
import * as Ast from 'frama-c/kernel/api/ast';
import * as States from 'frama-c/states';

const cFilter = {
  name: 'C source files',
  extensions: ['c', 'i', 'h'],
};
const allFilter = {
  name: 'all',
  extensions: ['*'],
};

async function parseFiles(files: string[]): Promise<void> {
  await Server.send(Ast.setFiles, files);
  await Server.send(Ast.compute, {});
  Display.showMessage('Source files parsed.');
  return;
}

async function setFiles(): Promise<void> {
  const files = await Dialogs.showOpenFiles({
    title: 'Select C source files',
    filters: [cFilter, allFilter],
  });
  if (files) {
    await parseFiles(files);
    States.clearHistory();
  }
  return;
}

async function addFiles(): Promise<void> {
  const dialog = Dialogs.showOpenFiles({
    title: 'Add C source files',
    filters: [cFilter, allFilter],
  });
  const request = Server.send(Ast.getFiles, {});
  const [oldFiles, newFiles] = await Promise.all([request, dialog]);
  if (newFiles) {
    const files = oldFiles ? oldFiles.concat(newFiles) : newFiles;
    parseFiles(files);
  }
  return;
}

async function reparseFiles(): Promise<void> {
  const files = await Server.send(Ast.getFiles, {});
  if (files) {
    await Server.send(Ast.setFiles, []);
    parseFiles(files);
  }
  return;
}

async function loadSession(): Promise<void> {
  const file = await Dialogs.showOpenFile({ title: 'Load a saved session' });
  const error = await Server.send(Services.load, file);
  States.clearHistory();
  if (error) {
    await Dialogs.showMessageBox({
      message: 'An error has occurred when loading the file',
      details: `File: ${file}\nError: ${error}`,
      kind: 'error',
      buttons: [{ label: 'Cancel' }],
    });
  }
  return;
}

async function saveSession(): Promise<void> {
  const title = 'Save the current session';
  const file = await Dialogs.showSaveFile({ title });
  const error = await Server.send(Services.save, file);
  if (error) {
    await Dialogs.showMessageBox({
      message: 'An error has occurred when saving the session',
      kind: 'error',
      buttons: [{ label: 'Cancel' }],
    });
  }
  return;
}

export function init(): void {
  ipcRenderer.invoke('dome.ipc.updateLearnMore', 'https://frama-c.com/');
  Dome.addMenuItem({
    menu: 'File',
    label: 'Set source files…',
    id: 'file_set',
    onClick: setFiles,
    kind: 'normal',
  });
  Dome.addMenuItem({
    menu: 'File',
    label: 'Add source files…',
    id: 'file_add',
    onClick: addFiles,
    kind: 'normal',
  });
  Dome.addMenuItem({
    menu: 'File',
    label: 'Reparse',
    id: 'file_reparse',
    onClick: reparseFiles,
    kind: 'normal',
  });
  Dome.addMenuItem({
    menu: 'File',
    id: 'file_separator',
    kind: 'separator',
  });
  Dome.addMenuItem({
    menu: 'File',
    label: 'Load session…',
    id: 'file_load',
    onClick: loadSession,
    kind: 'normal',
  });
  Dome.addMenuItem({
    menu: 'File',
    label: 'Save session…',
    id: 'file_save',
    onClick: saveSession,
    kind: 'normal',
  });
}

/* --------------------------------------------------------------------------*/
