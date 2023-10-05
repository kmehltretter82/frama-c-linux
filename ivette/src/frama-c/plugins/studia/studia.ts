/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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

import React from 'react';
import * as Dome from 'dome';
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Toolbars from 'dome/frame/toolbars';
import * as Status from 'frama-c/kernel/Status';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Locations from 'frama-c/kernel/Locations';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';
import { ipcRenderer } from 'electron';
import './style.css';

const studiaWritesEvent = new Dome.Event('dome.studia.writes');
const studiaReadsEvent = new Dome.Event('dome.studia.reads');
ipcRenderer.on('dome.ipc.studia.writes', () => studiaWritesEvent.emit());
ipcRenderer.on('dome.ipc.studia.reads', () => studiaReadsEvent.emit());

type access = 'Reads' | 'Writes';

async function computeStudiaSelection(
  kind: access,
  marker: Ast.marker,
  descr: string,
): Promise<void> {
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker);
  const markers = data.direct.map(([, m]) => m);
  const asLocs = markers.length > 0;
  const label = `${asLocs ? kind : `No ${kind.toLowerCase}`} of ${descr}`;
  const access = kind === 'Reads' ? 'accessing' : 'modifying';
  const tail = `the memory location pointed by ${descr}`;
  const title = asLocs ? `List of statements ${access} ${tail}.` : '';
  Locations.setSelection({ label, title, markers, index: 0 });
}

const isLval = (kind: Ast.markerKind):boolean => {
  switch(kind) {
    case 'LVAL':
    case 'LVAR':
    case 'DVAR':
      return true;
    default:
      return false;
  }
};

/** Builds the Studia entries in the contextual menu about a given marker.  */
export function buildMenu(
  menu: Dome.PopupMenuItem[],
  marker: Ast.marker,
  kind: Ast.markerKind,
  descr: string
): void {
  if (marker && isLval(kind)) {
    menu.push({
      label: `Studia: select reads of ${descr}`,
      onClick: () => computeStudiaSelection('Reads', marker, descr)
    });
    menu.push({
      label: `Studia: select writes of ${descr}`,
      onClick: () => computeStudiaSelection('Writes', marker, descr)
    });
  }
}

export function useStudiaMode(): void {
  const stmt = States.useSelected();
  async function onEnter(term: string, kind: access): Promise<void> {
    try {
      const marker = await Server.send(Ast.parseLval, { stmt, term });
      computeStudiaSelection(kind, marker, term);
    } catch(err) {
      const msg = `Studia failure: ${err}.`;
      Status.setMessage({ text: msg, kind: 'error' });
    }
  }
  const shared = {
    placeholder: "lvalue",
    icon: 'EDIT',
    className: 'studia-search-mode',
    hints: () => { return Promise.resolve([]); },
  };
  const writesMode = {
    ...shared,
    label: 'Studia: select writes',
    title: `Select all statements writing the given lvalue`,
    onEnter: (pattern:string) => onEnter(pattern, "Writes"),
    event: studiaWritesEvent,
  };
  const readsMode = {
    ...shared,
    label: 'Studia: select reads',
    title: `Selects all statements reading the given lvalue`,
    onEnter: (pattern:string) => onEnter(pattern, "Reads"),
    event: studiaReadsEvent,
  };
  React.useEffect(() => {
    Toolbars.RegisterMode.emit(writesMode);
    Toolbars.RegisterMode.emit(readsMode);
    return () => {
      Toolbars.UnregisterMode.emit(writesMode);
      Toolbars.UnregisterMode.emit(readsMode);
    };
  });
}
