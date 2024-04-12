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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Testing for Force Graph component                          --- */
/* -------------------------------------------------------------------------- */

import React from 'react';
import { Button } from 'dome/controls/buttons';
import {  Graph, Node, Edge, Layout } from 'dome/graph/graph';
import { registerSandbox } from 'ivette';

// --------------------------------------------------------------------------
// --- Init functions for nodes and edges
// --------------------------------------------------------------------------

function createNode(numberNode: number): Node[] {
  const nodes: Node[] = [];

  for (let i = 0; i < numberNode; i++) {
    const uniqueId = String(i);
    const newNode = { id: uniqueId, label: `Node: ${uniqueId}` };
    nodes.push(newNode);
  }

  return nodes;
}
function createEdge(nodes: Node[]): Edge[] {
  const edges: Edge[] = [];
  for (let i = 0; i < nodes.length - 1; i++) {
    const newEdge = { fromNode: nodes[i].id, toNode: nodes[i + 1].id };
    edges.push(newEdge);
  }
  return edges;
}

// --------------------------------------------------------------------------
// --- Main force graph component
// --------------------------------------------------------------------------

export default function GraphComponent(): JSX.Element {
  // Set initial configs
  const [nodes, setNodes] = React.useState<Node[]>(createNode(5));
  const [edges, setEdges] = React.useState<Edge[]>(createEdge(nodes));
  const [display, setDisplay] = React.useState<boolean>(true);
  const [layout, setLayout] = React.useState<Layout>('2D');
  const [zoom, setZoom] = React.useState<number>(2);
  const [nodeSelected, setNodeSelected] = React.useState<string>('0');

  // Display or hide the graph
  const updateDisplay = (): void => setDisplay(!display);

  // Add Node
  const addNode = (): void => {
    const uniqueId = String(nodes.length);
    const newNode = { id: uniqueId, label: `Node: ${uniqueId}` };
    const fromNodeId = nodes[nodes.length - 1].id;
    const newEdge = { fromNode: fromNodeId, toNode: newNode.id };

    setNodes((prevNodes) => ([...prevNodes, newNode]));
    setEdges((prevEdges) => ([...prevEdges, newEdge]));
  };

  // Remove Node GraphProps
  const deleteNode = (): void => {
    const newNodes = nodes.slice(0, -1);
    const newEdges = edges.slice(0, -1);
    setNodes(newNodes);
    setEdges(newEdges);
  };

  // Transition from 2D to 3D or 3D to 2D
  const updateLayout = (): void => {
    layout === '2D' ? setLayout('3D') : setLayout('2D');
  };

  // Zoom out
  const updateZoomOut = (): void => setZoom(zoom - 1);
  // Zoom In
  const updateZoomIn = (): void => setZoom(zoom + 1);

  const GraphChildren = ():JSX.Element => (
    <div className='toolbar'>
      <Button icon='DISPLAY' title='Display' onClick={updateDisplay} />
      <Button icon='COMPONENT' title='Layout' onClick={updateLayout} />
      <Button icon='ZOOM.IN' title='Zoom in' onClick={updateZoomIn} />
      <Button icon='ZOOM.OUT' title='Zoom out' onClick={updateZoomOut} />
      <Button icon='PLUS' title='Add' onClick={addNode} />
      <Button icon='MINUS' title='Delete' onClick={deleteNode} />
    </div>
  );

  return (
    <Graph
      nodes={nodes}
      edges={edges}
      selected={nodeSelected}
      zoom={zoom}
      layout={layout}
      display={display}
      className='dome-xGraph-item-graph'
      onSelection={(_n, _e) => { setNodeSelected(_n); }}
      onReady={() => {}}
    >
      <GraphChildren />
    </Graph>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.graph',
  label: 'Force Graph',
  children: <GraphComponent />,
});


// --------------------------------------------------------------------------
