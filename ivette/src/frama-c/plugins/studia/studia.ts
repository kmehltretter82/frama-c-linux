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
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';
import { ipcRenderer } from 'electron';
import './style.css';

const studiaWritesEvent = new Dome.Event('dome.studia.writes');
const studiaReadsEvent = new Dome.Event('dome.studia.reads');
ipcRenderer.on('dome.ipc.studia.writes', () => studiaWritesEvent.emit());
ipcRenderer.on('dome.ipc.studia.reads', () => studiaReadsEvent.emit());

type access = 'Reads' | 'Writes';
type Selections = Promise<States.MultipleSelect>;

interface ComputatationProps {
  marker: Ast.marker,
  label: string,
  kind: access,
}

async function compute(props: ComputatationProps): Selections {
  const { marker, label, kind } = props;
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker);
  const locations = data.direct.map(([f, m]) => ({ fct: f, marker: m }));
  const asLocs = locations.length > 0;
  const name = `${asLocs ? kind : `No ${kind.toLowerCase}`} of ${label}`;
  const access = kind === 'Reads' ? 'accessing' : 'modifying';
  const tail = `the memory location pointed by ${label}`;
  const title = asLocs ? `List of statements ${access} ${tail}.` : '';
  return { name, title, locations, index: 0 };
}

interface MenuProps {
  /** The marker on which the menu is applied. */
  marker: Ast.marker,
  /** Attributes of the marker. */
  attrs: Ast.markerAttributesData | undefined,
  /** Function to update the selection. */
  update: (a: States.SelectionActions) => void,
  /** Array to which studia menu entries are added. */
  menu: Dome.PopupMenuItem[],
}

/** Builds the Studia entries in the contextual menu about a given marker.  */
export function buildMenu(props: MenuProps) : void {
  const { update, marker, attrs, menu } = props;
  if (!attrs || !marker) return;
  const reads = 'Studia: select reads ';
  const writes = 'Studia: select writes ';
  if (attrs.isLval && !attrs.isFunction) {
    const data = { marker, label: attrs.name };
    const select = (k: access): Selections => compute({ ...data, kind: k });
    const onClick = (k: access): void => { select(k).then(update); };
    const suffix = `of ${attrs.name}`;
    const createMenuItem = (label: string, kind: access): void => {
      menu.push({ label: label + suffix, onClick: () => onClick(kind) });
    };
    createMenuItem(reads, 'Reads');
    createMenuItem(writes, 'Writes');
  } else {
    const location = { location: { fct: attrs.scope, marker } };
    const onClick = (e: Dome.Event): void => { update(location); e.emit(); };
    const suffix = `of…`;
    const createMenuItem = (label: string, evt: Dome.Event): void => {
      menu.push({ label: label + suffix, onClick: () => onClick(evt) });
    };
    createMenuItem(reads, studiaReadsEvent);
    createMenuItem(writes, studiaWritesEvent);
  }
}

export function useStudiaMode(): void {
  const [selection, setSelection] = States.useSelection();
  async function handleError(err: string): Promise<void> {
    const msg = `Studia failure: ${err}.`;
    Status.setMessage({ text: msg, kind: 'error' });
  }
  async function onEnter(label: string, kind: access): Promise<void> {
    const stmt = selection?.current?.marker;
    const data = { stmt, term: label };
    const marker = await Server.send(Ast.parseLval, data).catch(handleError);
    if (!marker) return;
    compute({ marker, label, kind }).then(setSelection).catch(handleError);
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
