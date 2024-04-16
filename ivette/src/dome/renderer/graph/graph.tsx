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
}

export type Layout = '2D' | '3D';

export interface Node extends Attributes {
  /** Node identifier (unique). */
  id: string;
}

export interface Edge extends Attributes {
  fromNode: string;
  toNode: string;
}

export type Callback = () => void;
export type SelectionCallback = (node: string, evt: MouseEvent) => void;

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

interface GraphData {
  nodes: {
    id: string;
    name: string | undefined;
  }[];
  links: {
    source: string;
    target: string;
  }[];
}

function Graph2D({
  graphData,
  zoom,
  onSelection,
}: {
  graphData: GraphData;
  zoom?: number;
  onSelection?: SelectionCallback;
}): JSX.Element {
  const fgRef2D = React.useRef<ForceGraphMethods2D | undefined>(undefined);

  React.useEffect(() => {
    // Zoom update on ForceGraph2D
    fgRef2D.current?.zoom(zoom || 0);
  }, [zoom]);

  return (
    <>
      <ForceGraph2D
        ref={fgRef2D}
        graphData={graphData}
        autoPauseRedraw={true}
        d3VelocityDecay={1}
        dagLevelDistance={50}
        onNodeClick={(node, event): void => {
          if (onSelection) onSelection(String(node.id), event);
        }}
        nodeLabel={'name'}
        cooldownTime={50}
      />
    </>
  );
}

function Graph3D({
  graphData,
  onSelection,
}: {
  graphData: GraphData;
  onSelection?: SelectionCallback;
}): JSX.Element {
  const fgRef3D = React.useRef<ForceGraphMethods3D | undefined>(undefined);
  return (
    <ForceGraph3D
      ref={fgRef3D}
      graphData={graphData}
      d3VelocityDecay={1}
      nodeLabel={'name'}
      onNodeClick={(node, event): void => {
        if (onSelection) onSelection(String(node.id), event);
      }}
      cooldownTime={50}
      dagLevelDistance={50}
    />
  );
}

export function Graph(props: GraphProps): JSX.Element {
  const [graphData, setGraphData] = React.useState<GraphData>({
    nodes: [],
    links: [],
  });

  React.useEffect(() => {
    const sortNodes: Node[] = props.nodes
      .slice()
      .sort((a: Node, b: Node) => Number(a.id) - Number(b.id));
    const sortEdges: Edge[] = props.edges
      .slice()
      .sort(
        (a, b) =>
          Number(a.fromNode) - Number(b.fromNode) &&
          Number(a.toNode) - Number(b.toNode)
      );

    if (graphData.nodes.length === 0) {
      setGraphData({
        nodes: sortNodes.map((node) => {
          return { id: node.id, name: node.label };
        }),
        links: sortEdges.map((edge) => {
          return { source: edge.fromNode, target: edge.toNode };
        }),
      });
    } else {
      setGraphData((prevGraph) => {
        if (sortNodes.length > prevGraph.nodes.length) {
          const newNode = {
            id: sortNodes[sortNodes.length - 1].id,
            name: sortNodes[sortNodes.length - 1].label,
          };

          const fromNodeId = prevGraph.nodes[prevGraph.nodes.length - 1].id;
          const newEdge = { source: fromNodeId, target: newNode.id };

          return {
            ...prevGraph,
            nodes: [...prevGraph.nodes, newNode],
            links: [...prevGraph.links, newEdge],
          };
        } else {
          if (sortNodes.length < prevGraph.nodes.length) {
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
    }
  }, [props.nodes, props.edges, graphData.nodes.length]);

  return (
    <div className={props.className}>
      {props.children}
      {props.display &&
        (props.layout === '2D' ? (
          <Graph2D
            graphData={graphData}
            zoom={props.zoom}
            onSelection={props.onSelection}
          />
        ) : (
          <Graph3D graphData={graphData} onSelection={props.onSelection} />
        ))}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
