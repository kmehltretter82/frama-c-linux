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

import * as Dome from 'dome';
import * as Ivette from 'ivette';
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Status from 'frama-c/kernel/Status';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Locations from 'frama-c/kernel/Locations';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';
import './style.css';

type access = 'Reads' | 'Writes';

function handleError(err: string): void {
  const text = `Studia failure: ${err}.`;
  Status.setMessage({ text, kind: 'error' });
}

async function computeStudiaSelection(
  kind: access,
  marker: Ast.marker,
  descr: string,
): Promise<void> {
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker).catch(handleError);
  const markers = data?.direct ?? [];
  if (markers.length > 0) {
    const label = `${kind} to ${descr}`;
    const access = kind === 'Reads' ? 'accessing' : 'modifying';
    const title =
      `Statements ${access} the memory location pointed by ${descr}.`;
    Locations.setSelection({
      plugin: 'Studia', label, title, markers, index: 0
    });
  } else {
    const label = `No ${kind.toLowerCase()} to ${descr}`;
    Locations.setSelection({
      plugin: 'Studia', label, markers: [], index: 0
    });
  }
}

/** Builds the Studia entries in the contextual menu about a given marker.  */
export function buildMenu(
  menu: Dome.PopupMenuItem[],
  attr: Ast.markerAttributesData,
): void {
  const { marker, kind } = attr;
  switch(kind) {
    case 'LVAL':
      menu.push({
        label: 'Studia: select reads of l-value',
        onClick: () => computeStudiaSelection('Reads', marker, attr.descr)
      });
      menu.push({
        label: 'Studia: select writes of l-value',
        onClick: () => computeStudiaSelection('Writes', marker, attr.descr)
      });
      return;
    case 'DVAR':
    case 'LVAR':
      {
        const name = attr.name || attr.descr;
        menu.push({
          label: `Studia: select reads of ${name}`,
          onClick: () => computeStudiaSelection('Reads', marker, name)
        });
        menu.push({
          label: `Studia: select writes of ${name}`,
          onClick: () => computeStudiaSelection('Writes', marker, name)
        });
      }
      return;
    case 'STMT':
      menu.push({
        label: `Studia: select reads of …`,
        onClick: () => Ivette.focusMode(studiaReadsMode.id)
      });
      menu.push({
        label: `Studia: select writes of …`,
        onClick: () => Ivette.focusMode(studiaWritesMode.id)
      });
      return;
  }
}

const studiaReadsMode : Ivette.ModeProps = {
  id: 'frama-c.plugins.studia.reads',
  rank: -1,
  label: 'Studia: reads',
  title: 'Select all statements reading the given lvalue',
  placeholder: 'lvalue (reads)',
  icon: 'EDIT',
  className: 'studia-search-mode',
  onEnter: (p: string) => onEnter('Reads', p)
};

const studiaWritesMode : Ivette.ModeProps = {
  id: 'frama-c.plugins.studia.writes',
  rank: -1,
  label: 'Studia: writes',
  title: 'Select all statements writing the given lvalue',
  placeholder: "lvalue (writes)",
  icon: 'EDIT',
  className: 'studia-search-mode',
  onEnter: (p: string) => onEnter('Writes', p)
};

async function onEnter(akind: access, term: string): Promise<void> {
  const stmt = States.getSelected();
  const { kind: mkind } = States.getMarker(stmt);
  if (mkind === 'STMT') {
    const marker = await Server.send(Ast.parseLval, { stmt, term })
      .catch(handleError);
    if (marker) computeStudiaSelection(akind, marker, term);
  }
}

Ivette.registerMode(studiaReadsMode);
Ivette.registerMode(studiaWritesMode);
States.GlobalHistory.on((s: States.History) => {
  const marker = s.curr.marker;
  const enabled = marker !== undefined;
  Ivette.updateMode({ id: studiaReadsMode.id, enabled });
  Ivette.updateMode({ id: studiaWritesMode.id, enabled });
});
