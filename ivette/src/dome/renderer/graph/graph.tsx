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

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export interface Attributes {
  label?: string;
  title?: string;
  className?: string;
}

export type Shape = "dot" | "box" | "circle";
export type ArrowType = "--" | "->" | "<-" | "<->";
export type Layout = "2D" | "3D";

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

// TO BE COMPLETE

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

  /** Layout engine. */
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

export function Graph(props: GraphProps): JSX.Element {
  const fgRef2D = React.useRef<ForceGraphMethods2D | undefined>(undefined);
  const fgRef3D = React.useRef<ForceGraphMethods3D | undefined>(undefined);
  const [graphData, setGraphData] = React.useState({
    nodes: props.nodes.map((node) => {
      return { id: node.id, name: node.label };
    }),
    links: props.edges.map((edge) => {
      return { source: edge.fromNode, target: edge.toNode };
    }),
  });

  // add and remove node on ForceGraph2D
  React.useEffect(() => {
    setGraphData((prevGraph) => {
      if (props.nodes.length > prevGraph.nodes.length) {
        const newNode = {
          id: props.nodes[props.nodes.length - 1].id,
          name: props.nodes[props.nodes.length - 1].label,
        };
        const fromNodeId = prevGraph.nodes[prevGraph.nodes.length - 1].id;
        const newEdge = { source: fromNodeId, target: newNode.id };

        return {
          ...prevGraph,
          nodes: [...prevGraph.nodes, newNode],
          links: [...prevGraph.links, newEdge],
        };
      } else {
        if (props.nodes.length < prevGraph.nodes.length) {
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
  }, [props.nodes, props.edges]);

  React.useEffect(() => {
    // Zoom update on ForceGraph2D
    fgRef2D.current?.zoom(props.zoom || 0);
    // fgRef3D.current?.zoomToFit(props.zoom);
  }, [props.zoom]);

  return (
    <div className={props.className}>
      {props.children}
      {props.display && (
        props.layout === '2D' ? (
          <ForceGraph2D
            ref={fgRef2D}
            graphData={graphData}
            // autoPauseRedraw performance optimization to automatically
            // pause redrawing the 2D canvas at every frame whenever
            // the simulation engine is halted
            autoPauseRedraw={true}
            // Nodes velocity decay that simulates the medium resistance.
            d3VelocityDecay={1}
            dagLevelDistance={50}
            // Node selection
            onNodeClick={(node, event): void => {
              if (props.onSelection)
                props.onSelection(String(node.id), event);
            }}
            nodeLabel={"name"}
            // How long (ms) to render for before stopping
            // and freezing the layout engine.
            cooldownTime={50}
            onRenderFramePost={(): void => {
              if (props.onReady)
                props.onReady();
            }}
          />
        ) : (
          <ForceGraph3D
            ref={fgRef3D}
            graphData={graphData}
            d3VelocityDecay={1}
            nodeLabel={"name"}
            onNodeClick={(node, event): void => {
              if (props.onSelection)
                props.onSelection(String(node.id), event);
            }}

            cooldownTime={50}
            dagLevelDistance={50}
          />
        )
      )}
    </div>
  );
}


/* -------------------------------------------------------------------------- */
