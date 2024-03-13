/* eslint-disable @typescript-eslint/no-unused-vars */
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

import React from 'react';
import { Button } from 'dome/frame/toolbars';
import { registerSandbox } from 'ivette';
import './sandbox.css';
import ForceGraph2D, {
  ForceGraphMethods as ForceGraphMethods2D,
} from 'react-force-graph-2d';
import ForceGraph3D, {
  ForceGraphMethods as ForceGraphMethods3D,
} from 'react-force-graph-3d';
import { v4 as uuidv4 } from 'uuid';

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export interface Attributes {
  label?: string;
  title?: string;
  className?: string;
}

export type Shape = 'dot' | 'box' | 'circle';
export type ArrowType = '--' | '->' | '<-' | '<->';
export type Layout = '2D' | '3D';

export interface Node extends Attributes {
  /** Node identifier (unique). */
  id: string;

  /** defaults to `"dot"` */
  shape?: Shape;
}

export interface Edge extends Attributes {
  fromNode: string;
  toNode: string;

  /** defaults to `"->"` */
  arrowType?: ArrowType;
}

export type Callback = () => void;
export type SelectionCallback = (node: string, evt: MouseEvent) => void;

/* -------------------------------------------------------------------------- */
/* --- Graph Implementation                                               --- */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface GraphProps {
  nodes: readonly Node[];
  edges: readonly Edge[];

  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: string;

  /** Force recomputing layout. */
  reset?: boolean;

  /**
     Zoom factor.
     Affects the viewport and the dimension of the nodes.
     When the zoom factor becomes to small, labels might be discarded.
   */
  zoom?: number;

  /** Kayout engine. */
  layout?: Layout;

  /** Invoked when a node is selected. */
  onSelection?: SelectionCallback;

  /** Invoked after layout is computed (typically used after a reset). */
  onReady?: Callback;

  /** Whether the Graph shall be displayed or not (defaults to true). */
  display?: boolean;

  /** Styling the Graph main div element. */
  className?: string;

  /** Elements to be inserted right inside the Graph main div element. */
  children?: React.ReactNode;
}

/* -------------------------------------------------------------------------- */
/* --- Graph Component                                                    --- */
/* -------------------------------------------------------------------------- */

export function Graph(props: {
  graph: GraphProps;
  setInitGraph: React.Dispatch<React.SetStateAction<GraphProps>>;
}): JSX.Element {
  const fgRef2D = React.useRef<ForceGraphMethods2D | undefined>(undefined);
  const fgRef3D = React.useRef<ForceGraphMethods3D | undefined>(undefined);
  const [graph2D, setGraph2D] = React.useState({
    nodes: props.graph.nodes.map((node) => {
      return { id: node.id, name: node.label };
    }),
    links: props.graph.edges.map((edge) => {
      return { source: edge.fromNode, target: edge.toNode };
    }),
  });

  // add and remove node on ForceGraph2D
  React.useEffect(() => {
    setGraph2D((prevGraph) => {
      if (props.graph.nodes.length > prevGraph.nodes.length) {
        const newNode = {
          id: props.graph.nodes[props.graph.nodes.length - 1].id,
          name: props.graph.nodes[props.graph.nodes.length - 1].label,
        };
        const fromNodeId = prevGraph.nodes[prevGraph.nodes.length - 1].id;
        const newEdge = { source: fromNodeId, target: newNode.id };

        return {
          ...prevGraph,
          nodes: [...prevGraph.nodes, newNode],
          links: [...prevGraph.links, newEdge],
        };
      } else {
        if (props.graph.nodes.length < prevGraph.nodes.length) {
          return {
            ...prevGraph,
            nodes: prevGraph.nodes.slice(0, -1),
            links: prevGraph.links.slice(0, -1),
          };
        } else {
          return { nodes: prevGraph.nodes, links: prevGraph.links };
        }
      }
    });
  }, [props.graph.nodes, props.graph.edges]);

  React.useEffect(() => {
    // Zoom update on ForceGraph2D
    fgRef2D.current?.zoom(props.graph.zoom || 0);
    // fgRef3D.current?.cameraPosition();
  }, [props.graph.zoom]);

  return (
    <div className={props.graph.className}>
      {props.graph.children}
      {props.graph.display ? (
        props.graph.layout === '2D' ? (
          <ForceGraph2D
            ref={fgRef2D}
            graphData={graph2D}
            // autoPauseRedraw performance optimization to automatically
            // pause redrawing the 2D canvas at every frame whenever
            // the simulation engine is halted
            autoPauseRedraw={true}
            // Nodes velocity decay that simulates the medium resistance.
            d3VelocityDecay={1}
            dagLevelDistance={50}
            // Node selection
            onNodeClick={(node, event): void => {
              if (props.graph.onSelection) {
                props.graph.onSelection(String(node.id), event);
              }
              // change the selected value of GraphProps
              props.setInitGraph((prevGraph) => {
                return { ...prevGraph, selected: String(node.id) };
              });
            }}
            onNodeDragEnd={(): void => {
              // Change x and y value on node ForceGraph2D
              setGraph2D((prevGraph) => {
                return { ...prevGraph };
              });
              // Change the x value and y value of GraphProps
              props.setInitGraph((prevGraph) => {
                return { ...prevGraph };
              });
            }}
            nodeLabel={'name'}
            // How long (ms) to render for before stopping
            // and freezing the layout engine.
            cooldownTime={1}
            onRenderFramePost={(): void => {
              if (props.graph.onReady) {
                props.graph.onReady();
              }
            }}
          />
        ) : (
          <ForceGraph3D
            ref={fgRef3D}
            graphData={graph2D}
            d3VelocityDecay={1}
            dagLevelDistance={50}
          />
        )
      ) : (
        <></>
      )}
    </div>
  );
}

export default function GraphComponent(): JSX.Element {
  const [initGraph, setInitGraph] = React.useState<GraphProps>(setGraph());
  // Generation of unique identifier
  function setGraph(N = 3): GraphProps {
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
      className: 'sandbox-item-graph',
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
  return (
    <>
      <Graph graph={initGraph} setInitGraph={setInitGraph} />
    </>
  );
}

registerSandbox({
  id: 'sandbox.graph',
  label: 'Graph Component',
  children: <GraphComponent />,
});
/* -------------------------------------------------------------------------- */
