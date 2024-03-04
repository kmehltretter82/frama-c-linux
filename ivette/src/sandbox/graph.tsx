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
// import other libs
import ForceGraph2D, {
  ForceGraphMethods as ForceGraphMethods2D,
} from 'react-force-graph-2d';
import ForceGraph3D, {
  ForceGraphMethods as ForceGraphMethods3D,
} from 'react-force-graph-3d';
import { v4 as uuidv4 } from 'uuid';
import './sandbox.css';
import { registerSandbox } from 'ivette';
import { Button } from 'dome/frame/toolbars';
import { nodeDefault } from 'frama-c/plugins/dive/api';

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

export interface Node<ID> extends Attributes {
  /** Node identifier (unique). */
  id: ID;

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
export type SelectionCallback = (node: string, evt: React.MouseEvent) => void;

/* -------------------------------------------------------------------------- */
/* --- Graph Implementation                                               --- */
/* -------------------------------------------------------------------------- */
export type MapGraph = (nodes: Node<string>[], edges: Edge[]) => void;

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface GraphProps<ID> {
  nodes: readonly Node<ID>[];
  edges: readonly Edge[];

  /** Converts nodes and edges for ForceGraph */
  mapGraph?: MapGraph;
  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: ID;

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
  graph: GraphProps<string>;
  setInitGraph: React.Dispatch<React.SetStateAction<GraphProps<string>>>;
}): JSX.Element {
  const fgRef2D = React.useRef<ForceGraphMethods2D | undefined>(undefined);
  const fgRef3D = React.useRef<ForceGraphMethods3D | undefined>(undefined);
  // const graph = props.mapGraph( props.nodes, props.edges);
  const graph = {
    nodes: props.graph.nodes.map((node) => {
      return { id: node.id, name: node.label };
    }),
    links: props.graph.edges.map((edge) => {
      return { source: edge.fromNode, target: edge.toNode };
    }),
  };

  // Zoom update on ForceGraph2D
  React.useEffect(() => {
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
            graphData={graph}
            // autoPauseRedraw performance optimization to automatically
            // pause redrawing the 2D canvas at every frame whenever
            // the simulation engine is halted
            autoPauseRedraw={true}
            // Sets the simulation alpha min parameter.
            d3AlphaDecay={1}
            d3VelocityDecay={1}
            dagLevelDistance={50}
            // Node selection
            onNodeClick={(node): void => {
              props.setInitGraph({ ...props.graph, selected: String(node.id) });
            }}
            nodeLabel={'name'}
            // eslint-disable-next-line no-console
            // onRenderFramePost={() => console.log('end draw')}
          />
        ) : (
          <ForceGraph3D ref={fgRef3D} graphData={graph} />
        )
      ) : (
        <></>
      )}
    </div>
  );
}

export default function GraphComponent(): JSX.Element {
  const [initGraph, setInitGraph] =
    React.useState<GraphProps<string>>(setGraph());
  /*
  React.useEffect(() => {
    // eslint-disable-next-line no-console
    console.log(initGraph.selected);
  }, [initGraph.selected]);
  */

  // Generation of unique identifier
  function setGraph(N = 3): GraphProps<string> {
    function generateUUIDs(): string[] {
      const uuidArray: string[] = [];

      for (let i = 0; i < N; i++) {
        uuidArray.push(uuidv4());
      }

      return uuidArray;
    }
    const uniqueIds = generateUUIDs();

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
          <Button title='Layout' icon='COMPONENT' onClick={updateLayout} />
          <Button icon='ZOOM.IN' title={'Zoom in'} onClick={updateZoomIn} />
          <Button icon='ZOOM.OUT' title={'Zoom out'} onClick={updateZoomOut} />
        </div>
      ),
    };
  }
  return (
    <>
      {/* <Graph {...initGraph} /> */}
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
