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
/* --- Frama-C Selection History                                          ---*/
/* --------------------------------------------------------------------------*/

import React from 'react';
import * as Toolbar from 'dome/frame/toolbars';
import * as States from 'frama-c/states';

export default function History(): JSX.Element {
  const history = States.useHistory();
  const prev = history.prev[0]?.scope;
  const next = history.next[0]?.scope;
  const { label: prevLabel } = States.useDeclaration(prev);
  const { label: nextLabel } = States.useDeclaration(next);
  const prevTitle = prevLabel || 'Previous location';
  const nextTitle = nextLabel || 'Next location';
  return (
    <Toolbar.ButtonGroup>
      <Toolbar.Button
        icon="ANGLE.LEFT"
        onClick={States.gotoPrev}
        enabled={history.prev.length > 0}
        title={prevTitle}
      />
      <Toolbar.Button
        icon="ANGLE.RIGHT"
        onClick={States.gotoNext}
        enabled={history.next.length > 0}
        title={nextTitle}
      />
    </Toolbar.ButtonGroup>
  );
}

/* --------------------------------------------------------------------------*/
