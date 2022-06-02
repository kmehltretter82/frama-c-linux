/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Ivette Component.                                          --- */
/* --- Only appears in DEVEL mode.                                        --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
//import * as Dome from 'dome';
//import * as Ctrl from 'dome/controls/buttons';
import * as Disp from 'dome/controls/displays';
import * as Box from 'dome/layout/boxes';
import * as DnD from 'dome/newdnd';
import { registerSandbox } from 'ivette';

function UseDnD(): JSX.Element {
  const [state, setState] = React.useState('--');
  //const [blink, setBlink] = React.useState(false);
  return (
    <Box.Vfill>
      <Box.Hbox>
        <Disp.LCD label={state} />
      </Box.Hbox>
      <DnD.DragSource
        onStart={() => setState('??')}
        onDrag={(x, y) => setState(`${x}:${y}`)}
        onStop={() => setState('--')}
      >
        Using Drag & Drop
      </DnD.DragSource>
    </Box.Vfill>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.usednd',
  label: 'Drag & Drop',
  children: <UseDnD />,
});

/* -------------------------------------------------------------------------- */
