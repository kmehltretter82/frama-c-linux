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
import ForceGraph2D from 'react-force-graph-2d';
import ForceGraph3D from 'react-force-graph-3d';
import './sandbox.css';
import { registerSandbox } from 'ivette';
import { Button } from 'dome/frame/toolbars';

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

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface GraphProps<ID> {
  nodes: readonly Node<ID>[];
  edges: readonly Edge[];

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

export function Graph(props: GraphProps<string>): JSX.Element {
  const graph = {
    nodes: props.nodes.map((node) => {
      return { id: Number(node.id) };
    }),
    links: props.edges.map((edge) => {
      return { source: Number(edge.fromNode), target: Number(edge.toNode) };
    }),
  };

  return (
    <div className={props.className}>
      {props.children}
      {props.display ? (
        props.layout === '2D' ? (
          <ForceGraph2D
            graphData={graph}
            // autoPauseRedraw performance optimization to automatically
            // pause redrawing the 2D canvas at every frame whenever
            // the simulation engine is halted
            autoPauseRedraw={true}
            // Sets the simulation alpha min parameter.
            d3AlphaDecay={1}
            d3VelocityDecay={1}
            dagLevelDistance={50}
          />
        ) : (
          <ForceGraph3D graphData={graph} />
        )
      ) : (
        <></>
      )}
    </div>
  );
}

function GraphComponent(): JSX.Element {
  const [initGraph, setInitGraph] = React.useState<GraphProps<string>>(
    genRandomTree() as GraphProps<string>
  );

  function genRandomTree(): GraphProps<string> {
    return {
      nodes: [{ id: '0' }, { id: '1' }],
      edges: [{ fromNode: '0', toNode: '1' }],
      selected: '0',
      zoom: 1,
      layout: '2D',
      display: true,
      className: 'sandbox-item-graph',
      children: (
        <div className='buttons'>
          <Button
            icon='DISPLAY'
            title='Display'
            onClick={() => {
              setInitGraph((prevGraph) => {
                return { ...prevGraph, display: !prevGraph.display };
              });
            }}
          />
          <Button
            title='Layout'
            icon='COMPONENT'
            onClick={() => {
              setInitGraph((prevGraph) => {
                return {
                  ...prevGraph,
                  layout: prevGraph.layout === '2D' ? '3D' : '2D',
                };
              });
            }}
          />
        </div>
      ),
    };
  }
  return (
    <>
      <Graph {...initGraph} />
    </>
  );
}

// const initGraph = genRandomTree();
registerSandbox({
  id: 'sandbox.graph',
  label: 'Graph Component',
  children: <GraphComponent />,
});
/* -------------------------------------------------------------------------- */
