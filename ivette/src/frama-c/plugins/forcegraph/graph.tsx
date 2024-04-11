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

import React from "react";
import { Button } from "dome/controls/buttons";
import { GraphProps, Graph } from "dome/graph/graph";
import { v4 as uuidv4 } from 'uuid';
import './style.css';

export default function GraphComponent(): JSX.Element {
  const [initGraph, setInitGraph] = React.useState<GraphProps>(setGraph());
  function setGraph(N = 3): GraphProps {
    // Generation of unique identifier
    function generateUUIDs(): string[] {
      const uuidArray: string[] = [];

      for (let i = 0; i < N; i++) {
        uuidArray.push(uuidv4());
      }

      return uuidArray;
    }
    const uniqueIds = generateUUIDs();

    // add Node GraphProps
    const addNode = (): void => {
      const uniqueId = uuidv4();
      const newNode = { id: uniqueId, label: `Node: ${uniqueId}` };
      setInitGraph((prevGraph) => {
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
    // Display or hide the graph
    const updateDisplay = (): void => {
      setInitGraph((prevGraph) => {
        return { ...prevGraph, display: !prevGraph.display };
      });
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

    return {
      nodes: [
        { id: uniqueIds[0], label: `Node: ${uniqueIds[0]}` },
        { id: uniqueIds[1], label: `Node: ${uniqueIds[1]}` },
        { id: uniqueIds[2], label: `Node: ${uniqueIds[2]}` },
      ],
      edges: [
        { fromNode: uniqueIds[0], toNode: uniqueIds[1] },
        { fromNode: uniqueIds[1], toNode: uniqueIds[2] },
      ],
      selected: '0',
      zoom: 2,
      layout: '2D',
      display: true,
      className: 'forcegraph-item-graph',
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
  }
  return <>
  <Graph graph={initGraph} setInitGraph={setInitGraph} />
  </>;
}
