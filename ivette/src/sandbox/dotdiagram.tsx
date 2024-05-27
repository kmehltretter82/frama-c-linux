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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Testing for Diagram component                              --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import { Scroll } from 'dome/layout/boxes';
import { HSplit } from 'dome/layout/splitters';
import { Diagram, Node, Edge } from 'dome/graph/diagram';
import { registerSandbox } from 'ivette';

// --------------------------------------------------------------------------
// --- Init functions for nodes and edges
// --------------------------------------------------------------------------

const nodes: Node[] = [
  { id: 'A' },
  { id: 'B', shape: 'diamond' },
  {
    id: 'R',
    shape: [
      { label: 'Dotted "c"', port: 'c' },
      ['D1', 'D2'],
      { label: 'Dashed "e"', port: 'e' },
    ]
  },
  { id: 'white', color: 'white' },
  { id: 'grey', color: 'grey' },
  { id: 'dark', color: 'dark' },
  { id: 'primary', color: 'primary' },
  { id: 'selected', color: 'selected' },
  { id: 'green', color: 'green' },
  { id: 'orange', color: 'orange' },
  { id: 'red', color: 'red' },
  { id: 'yellow', color: 'yellow' },
  { id: 'blue', color: 'blue' },
  { id: 'pink', color: 'pink' },
  { id: 'X' }, { id: 'Y' }
];

const edges: Edge[] = [
  { source: 'A', target: 'R', targetPort: 'c', headLabel: 'c', line: 'dotted' },
  { source: 'R', target: 'B', sourcePort: 'e', tailLabel: 'e', line: 'dashed' },
  { source: 'primary', target: 'selected' },
  { source: 'white', target: 'grey' },
  { source: 'grey', target: 'dark' },
  { source: 'green', target: 'orange' },
  { source: 'orange', target: 'red' },
  { source: 'yellow', target: 'pink' },
  { source: 'pink', target: 'blue' },
  { source: 'white', target: 'white', color: 'white' },
  { source: 'grey', target: 'grey', color: 'grey' },
  { source: 'dark', target: 'dark', color: 'dark' },
  { source: 'primary', target: 'primary', color: 'primary' },
  { source: 'selected', target: 'selected', color: 'selected' },
  { source: 'green', target: 'green', color: 'green' },
  { source: 'orange', target: 'orange', color: 'orange' },
  { source: 'red', target: 'red', color: 'red' },
  { source: 'yellow', target: 'yellow', color: 'yellow' },
  { source: 'blue', target: 'blue', color: 'blue' },
  { source: 'pink', target: 'pink', color: 'pink' },
  {
    source: 'X', target: 'Y',
    tail: 'box', head: 'dot',
    label: '*', title: 'box to dot'
  },
];

function DiagramSample(): JSX.Element {
  const [model, setModel] = React.useState('');
  const [selected, setSelected] = React.useState<string>();
  return (
    <HSplit settings='sandbox.diagram.split'>
      <Scroll>
        <pre>Selected: {selected}</pre>
        <pre>
          {model}
        </pre>
      </Scroll>
      <Diagram
        nodes={nodes}
        edges={edges}
        selected={selected}
        onModelChanged={setModel}
        onSelection={setSelected}
      />
    </HSplit >
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.diagram',
  label: 'Diagram',
  preferredPosition: 'ABCD',
  children: <DiagramSample />,
});

// --------------------------------------------------------------------------
