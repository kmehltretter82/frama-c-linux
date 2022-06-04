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

interface BlobProps {
  id: string;
  setState: (s: string) => void;
}

function Blob(props: BlobProps): JSX.Element {
  const { id, setState } = props;
  return (
    <DnD.DragSource
      className='sandbox-item'
      styleDragging={{ background: 'lightgreen' }}
      onStart={() => setState(id)}
      onDrag={(d) => setState(delta(id, d))}
      onStop={() => setState('--')}
    >
      Blob #{id}
    </DnD.DragSource>
  );
}

function Item({ id }: { id: string }): JSX.Element {
  return <DnD.Item className='sandbox-item' id={id}>Item {id}</DnD.Item>;
}

function UseDnD(): JSX.Element {
  const [state, setState] = React.useState('--');
  return (
    <Box.Vfill>
      <Box.Hbox>
        <LCD label={state} />
      </Box.Hbox>
      <Box.Hbox>
        <Box.Vbox>
          <DnD.List>
            <Item id='A' />
            <Item id='B' />
            <Item id='C' />
            <Item id='D' />
            <Item id='E' />
          </DnD.List>
        </Box.Vbox>
        <Box.Vbox>
          <Blob id='A' setState={setState} />
          <Blob id='B' setState={setState} />
          <Blob id='C' setState={setState} />
        </Box.Vbox>
      </Box.Hbox>
    </Box.Vfill >
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
