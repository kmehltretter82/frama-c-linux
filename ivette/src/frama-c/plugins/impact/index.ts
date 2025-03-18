/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2025                                                */
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
import * as Display from 'ivette/display';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import * as ASTview from 'frama-c/kernel/ASTview';
import * as Locations from 'frama-c/kernel/Locations';
import { impactStatement } from 'frama-c/plugins/impact/api/impact';
import './style.css';

function handleError(err: string): void {
  Display.showWarning({ label: 'Impact failure', title: `Error (${err})` });
}

/* Calls impact analysis on [attr], and selects the list of returned markers. */
async function computeStatement(attr: Ast.markerAttributesData): Promise<void> {
  const { marker, descr } = attr;
  const data = await Server.send(impactStatement, marker).catch(handleError);
  const markers = data ?? [];
  const label = `Impact of ${descr}`;
  const title = `List of statements impacted by statement ${descr}.`;
  Locations.setSelection({
    plugin: 'Impact', label, title, markers
  });
}

/* Builds the Impact entry in the contextual menu about a statement. */
function buildMenu(
  menu: Dome.PopupMenuItem[],
  attr: Ast.markerAttributesData,
): void {
  switch (attr.kind) {
    case 'STMT':
      menu.push({
        label: 'Impact analysis',
        onClick: () => computeStatement(attr)
      });
      return;
  }
}

ASTview.registerMarkerMenuExtender(buildMenu);
