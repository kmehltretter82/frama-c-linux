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
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import { getWritesLval, getReadsLval } from 'frama-c/plugins/studia/api/studia';

type access = 'Reads' | 'Writes';

async function compute(marker: Ast.marker, label: string, kind: access)
  : Promise<States.MultipleSelect> {
  const request = kind === 'Reads' ? getReadsLval : getWritesLval;
  const data = await Server.send(request, marker);
  const locations = data.direct.map(([f, m]) => ({ fct: f, marker: m }));
  if (locations.length > 0) {
    const name = `${kind} of ${label}`;
    const acc = (kind === 'Reads') ? 'accessing' : 'modifying';
    const title =
      `List of statements ${acc} the memory location pointed by ${label}.`;
    return { name, title, locations, index: 0 };
  }
  const name = `No ${kind.toLowerCase()} of ${label}`;
  return { name, title: '', locations: [], index: 0 };
}

interface MenuProps {
  /** The marker on which the menu is applied. */
  marker: Ast.marker,
  /** Attributes of the marker. */
  attrs?: Ast.markerAttributesData,
  /** Function to update the selection. */
  update: (a: States.SelectionActions) => void,
  /** Array to which studia menu entries are added. */
  menu: Dome.PopupMenuItem[],
}

/** Builds the Studia entries in the contextual menu about a given marker.  */
export function buildMenu(props: MenuProps) : void {
  const { update, marker, attrs, menu } = props;
  const enabled = attrs?.isLval;
  function onClick(kind: access) : void {
    if (marker && attrs)
      compute(marker, attrs.name, kind).then(update);
  }
  const reads = 'Studia: select reads';
  const writes = 'Studia: select writes';
  menu.push({ label: reads, enabled, onClick: () => onClick('Reads') });
  menu.push({ label: writes, enabled, onClick: () => onClick('Writes') });
}
