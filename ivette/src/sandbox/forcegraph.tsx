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

import { registerSandbox } from 'ivette';
import React, { useEffect } from 'react';
import { Button } from 'dome/controls/buttons';
import { GraphProps, Graph, Node, Edge } from 'dome/graph/graph';

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
  const nodes = createNode(5);
  const edges = createEdge(nodes);
  const [initGraph, setInitGraph] = React.useState<GraphProps>({
    nodes,
    edges,
  });

  // Display or hide the graph
  const updateDisplay = (): void => {
    setInitGraph((p) => {
      return { ...p, display: !p.display };
    });
  };

  // add Node GraphProps
  const addNode = (): void => {
    setInitGraph((prevGraph) => {
      const uniqueId = String(prevGraph.nodes.length);
      const newNode = { id: uniqueId, label: `Node: ${uniqueId}` };
      const fromNodeId = prevGraph.nodes[prevGraph.nodes.length - 1].id;
      const newEdge = { fromNode: fromNodeId, toNode: newNode.id };
      return {
        ...prevGraph,
        nodes: [...prevGraph.nodes, newNode],
        edges: [...prevGraph.edges, newEdge],
      };
    });
  };

  // Remove Node GraphProps
  const deleteNode = (): void => {
    setInitGraph((prevState) => ({
      ...prevState,
      nodes: prevState.nodes.slice(0, -1),
      edges: prevState.edges.slice(0, -1),
    }));
  };

  // Transition from 2D to 3D or 3D to 2D
  const updateLayout = (): void => {
    setInitGraph((prevGraph) => {
      return {
        ...prevGraph,
        layout: prevGraph.layout === '2D' ? '3D' : '2D',
      };
    });
  };

  // Zoom out
  const updateZoomOut = (): void => {
    setInitGraph((prevGraph) => {
      return {
        ...prevGraph,
        zoom: prevGraph.zoom! - 1,
      };
    });
  };
  // Zoom In
  const updateZoomIn = (): void => {
    setInitGraph((initGraph) => {
      return {
        ...initGraph,
        zoom: initGraph.zoom! + 1,
      };
    });
  };

  useEffect(() => {
    setInitGraph((p) => {
      return {
        ...p,
        selected: '0',
        zoom: 2,
        layout: '2D',
        display: true,
        className: 'dome-xGraph-item-graph',
        children: (
          <div className='toolbar'>
            <Button icon='DISPLAY' title='Display' onClick={updateDisplay} />
            <Button icon='COMPONENT' title='Layout' onClick={updateLayout} />
            <Button icon='ZOOM.IN' title='Zoom in' onClick={updateZoomIn} />
            <Button icon='ZOOM.OUT' title='Zoom out' onClick={updateZoomOut} />
            <Button icon='PLUS' title='Add' onClick={addNode} />
            <Button icon='MINUS' title='Delete' onClick={deleteNode} />
          </div>
        ),

        onSelection: (_n, _e) => {},
        onReady: () => {},
      };
    });
  }, []);

  return <Graph graph={initGraph} setInitGraph={setInitGraph} />;
}

// --------------------------------------------------------------------------
/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

registerSandbox({
  id: 'sandbox.icons',
  label: 'Force Graph',
  title: 'Display a graph showing calls between functions.',
  children: <GraphComponent />,
});

/* -------------------------------------------------------------------------- */
