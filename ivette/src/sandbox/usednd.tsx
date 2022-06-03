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
import { LCD } from 'dome/controls/displays';
import * as Box from 'dome/layout/boxes';
import * as DnD from 'dome/newdnd';
import { registerSandbox } from 'ivette';
import './sandbox.css';

const delta = (id: string, d: DnD.Dragging): string => {
  const dx = d.dragX - d.rootX;
  const dy = d.dragY - d.rootY;
  return `${id} ${dx}:${dy}`;
};

interface ItemProps {
  id: string;
  setState: (s: string) => void;
}

function Item(props: ItemProps): JSX.Element {
  const { id, setState } = props;
  return (
    <DnD.DragSource
      className='sandbox-item'
      styleDragging={{ background: 'lightgreen' }}
      onStart={() => setState(id)}
      onDrag={(d) => setState(delta(id, d))}
      onStop={() => setState('--')}
    >
      Item {id}
    </DnD.DragSource>
  );
}

function UseDnD(): JSX.Element {
  const [state, setState] = React.useState('--');
  return (
    <Box.Vfill>
      <Box.Hbox>
        <LCD label={state} />
      </Box.Hbox>
      <Box.Vbox>
        <Item id='A' setState={setState} />
        <Item id='B' setState={setState} />
        <Item id='C' setState={setState} />
      </Box.Vbox>
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
