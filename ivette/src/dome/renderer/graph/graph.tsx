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

import ForceGraph2D from 'react-force-graph-2d';
// ForceGraphMethods as ForceGraphMethods2D,
import ForceGraph3D from 'react-force-graph-3d';
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
  source: string; /** Source node identifier */
  target: string; /** Target node identifier */
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

interface GNode { id: string, label?: string }
interface GLink { source: string, target: string }
interface GData { nodes: GNode[], links: GLink[] }

interface GProps {
  data: GData;
  onSelection?: SelectionCallback;
}

/* -------------------------------------------------------------------------- */
/* --- 2D Force Graph Component                                           --- */
/* -------------------------------------------------------------------------- */

function Graph2D(props: GProps): JSX.Element {
  const { data, onSelection } = props;
  // const fgRef2D = React.useRef<ForceGraphMethods2D | undefined>(undefined);
  return (
    <>
      <ForceGraph2D<GNode, GLink>
        // ref={fgRef2D}
        nodeId='id'
        nodeLabel='label'
        linkSource='source'
        linkTarget='target'
        graphData={data}
        autoPauseRedraw={true}
        d3VelocityDecay={1}
        dagLevelDistance={50}
        onNodeClick={(node, event): void => {
          if (onSelection) onSelection(node.id, event);
        }}
        cooldownTime={50}
      />
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- 3D Force Graph Component                                           --- */
/* -------------------------------------------------------------------------- */

function Graph3D(props: GProps): JSX.Element {
  const { data, onSelection } = props;
  // const fgRef3D = React.useRef<ForceGraphMethods3D | undefined>(undefined);
  return (
    <ForceGraph3D<GNode, GLink>
      // ref={fgRef3D}
      nodeId='id'
      nodeLabel='label'
      linkSource='source'
      linkTarget='target'
      graphData={data}
      d3VelocityDecay={1}
      onNodeClick={(node, event): void => {
        if (onSelection) onSelection(node.id, event);
      }}
      cooldownTime={50}
      dagLevelDistance={50}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* --- Dome Graph Component                                               --- */
/* -------------------------------------------------------------------------- */

export function Graph(props: GraphProps): JSX.Element {
  const { nodes, edges, onSelection, display = true } = props;
  const data: GData = React.useMemo(() => ({
    nodes: nodes.slice(),
    links: edges.slice(),
  }), [nodes, edges]);
  return (
    <div className={props.className}>
      {display && props.layout === '2D' &&
        <Graph2D key='2D' data={data} onSelection={onSelection} />}
      {display && props.layout === '3D' &&
        <Graph3D key='3D' data={data} onSelection={onSelection} />}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
