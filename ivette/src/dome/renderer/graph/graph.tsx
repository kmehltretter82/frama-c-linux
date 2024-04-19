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

import ForceGraph2D, {
  ForceGraphMethods as ForceGraphMethods2D,
  LinkObject as LinkObject2D,
  NodeObject as NodeObject2D,
} from 'react-force-graph-2d';

import ForceGraph3D, {
  ForceGraphMethods as ForceGraphMethods3D,
  LinkObject as LinkObject3D,
  NodeObject as NodeObject3D,
} from 'react-force-graph-3d';
// ForceGraphMethods as ForceGraphMethods3D,

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export type Layout = '2D' | '3D';

export interface Node {
  /** Node identifier (unique). */
  id: string;
  /** Node label (optional). */
  label?: string;
}

export interface Edge {
  source: string /** Source node identifier */;
  target: string /** Target node identifier */;
}

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export type Callback = () => void;
export type SelectionCallback = (node: string, evt: MouseEvent) => void;

export interface GraphProps {
  nodes: readonly Node[];
  edges: readonly Edge[];

  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: string;

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
}

/* -------------------------------------------------------------------------- */
/* --- Force Graph Components                                             --- */
/* -------------------------------------------------------------------------- */

interface GNode {
  id: string;
  label?: string;
}
interface GLink {
  source: string;
  target: string;
}
interface GData {
  nodes: GNode[];
  links: GLink[];
}

interface GProps {
  data: GData;
  onSelection?: SelectionCallback;
  selected: string | undefined;
}

/* -------------------------------------------------------------------------- */
/* --- 2D Force Graph Component                                           --- */
/* -------------------------------------------------------------------------- */

function Graph2D(props: GProps): JSX.Element {
  const { data, onSelection, selected } = props;
  const fgRef2D = React.useRef<
    | ForceGraphMethods2D<NodeObject2D<GNode>, LinkObject2D<GNode, GLink>>
    | undefined
  >(undefined);
  React.useEffect(() => {
    if (fgRef2D.current && selected) {
      const selectedNode: NodeObject2D | undefined = data.nodes.find(
        (node) => node.id === selected
      );
      if (selectedNode)
        fgRef2D.current.centerAt(selectedNode.x, selectedNode.y, 500);
    }
  }, [selected, data]);
  return (
    <>
      <ForceGraph2D<GNode, GLink>
        ref={fgRef2D}
        nodeId='id'
        nodeLabel='label'
        linkSource='source'
        linkTarget='target'
        graphData={data}
        autoPauseRedraw={true}
        // default value of intensity
        d3AlphaDecay={0.0228}
        dagLevelDistance={50}
        onNodeClick={(node, event): void => {
          if (onSelection) onSelection(node.id, event);
        }}
        // Fix target position on drag end
        onNodeDragEnd={(node) => {
          node.fx = node.x;
          node.fy = node.y;
        }}
        cooldownTime={50}
        nodeColor={(node) => (node.id === selected ? '#F4D03F' : '#5DADE2')}
      />
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- 3D Force Graph Component                                           --- */
/* -------------------------------------------------------------------------- */

function Graph3D(props: GProps): JSX.Element {
  const { data, onSelection, selected } = props;
  const fgRef3D = React.useRef<
    | ForceGraphMethods3D<NodeObject3D<GNode>, LinkObject3D<GNode, GLink>>
    | undefined
  >(undefined);
  React.useEffect(() => {
    if (fgRef3D.current && selected) {
      // distance to set between camera and node
      const distance = 100;
      const selectedNode: NodeObject3D | undefined = data.nodes.find(
        (node) => node.id === selected
      );
      if (selectedNode) {
        const { x, y, z } = selectedNode;
        if (x && y && z) {
          const distRatio = 1 + distance / Math.hypot(x, y, z);
          fgRef3D.current.cameraPosition(
            // new position
            { x: x * distRatio, y: y * distRatio, z: z * distRatio },
            { x, y, z }, // lookAt Parameter
            1000 // ms transition duration
          );
        }
      }
    }
  }, [selected, data]);
  return (
    <ForceGraph3D<GNode, GLink>
      ref={fgRef3D}
      nodeId='id'
      nodeLabel='label'
      linkSource='source'
      linkTarget='target'
      graphData={data}
      d3AlphaDecay={0.0228}
      onNodeClick={(node, event): void => {
        if (onSelection) onSelection(node.id, event);
      }}
      cooldownTime={50}
      dagLevelDistance={50}
      controlType='orbit'
      // Fix target position on drag end
      onNodeDragEnd={(node) => {
        node.fx = node.x;
        node.fy = node.y;
        node.fz = node.z;
      }}
      nodeColor={(node) => (node.id === selected ? '#F4D03F' : '#5DADE2')}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* --- Dome Graph Component                                               --- */
/* -------------------------------------------------------------------------- */

export function Graph(props: GraphProps): JSX.Element {
  const { nodes, edges, onSelection, display = true, selected } = props;
  const data: GData = React.useMemo(
    () => ({
      nodes: nodes.slice(),
      links: edges.slice(),
    }),
    [nodes, edges]
  );
  return (
    <div className={props.className}>
      {display && props.layout === '2D' && (
        <Graph2D
          key='2D'
          data={data}
          onSelection={onSelection}
          selected={selected}
        />
      )}
      {display && props.layout === '3D' && (
        <Graph3D
          key='3D'
          data={data}
          onSelection={onSelection}
          selected={selected}
        />
      )}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
