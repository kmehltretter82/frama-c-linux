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

const nodes : Node[] = [
  { id: 'A' },
  { id: 'B' },
];

const edges : Edge[] = [
  { source: 'A', target: 'B' }
];

function DiagramSample(): JSX.Element {
  const [model, setModel] = React.useState('');
  return (
    <HSplit settings='sandbox.diagram.split'>
      <Scroll>
        <pre>
          {model}
        </pre>
      </Scroll>
      <Diagram
        nodes={nodes}
        edges={edges}
        onModelChanged={setModel}
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
