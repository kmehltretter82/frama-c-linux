/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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
import { Scroll } from 'dome/layout/boxes';
import { Size } from 'react-virtualized';
import AutoSizer from 'react-virtualized-auto-sizer';

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export type Direction = 'LR' | 'TD';

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

export interface DiagramProps {
  nodes: readonly Node[];
  edges: readonly Edge[];

  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: string;

  /** Top-Down (`'TD'`, default) or Left-Right (`'LR'`) direction. */
  direction?: Direction;

  /** Invoked when a node is selected. */
  onSelection?: (node: string, evt: MouseEvent) => void;

  /** Whether the Graph shall be displayed or not (defaults to true). */
  display?: boolean;

  /** Styling the Graph main div element. */
  className?: string;

  /** Debug the generated DotModel */
  onModelChanged?: (model: string) => void;

}

/* -------------------------------------------------------------------------- */
/* --- Dot Model                                                          --- */
/* -------------------------------------------------------------------------- */

type edgeSpec = { source: string, target: string };
const edgeKey = (e: edgeSpec): string => `${e.source} -> ${e.target}`;

class DotModel {

  // --- Basics
  private spec = 'digraph {\n';
  print(...text: string[]): DotModel {
    this.spec = this.spec.concat(...text);
    return this;
  }
  println(...text: string[]): DotModel {
    this.spec = this.spec.concat(...text).concat('\n');
    return this;
  }
  flush(): string { return this.spec.concat('}'); }

  // --- Graph
  rankdir(d: Direction): DotModel {
    return this.println('  rankdir="', d, '";');
  }

  // --- Special
  quoted(a: string): DotModel { return this.print('"', a, '"'); }

  // --- Node
  node(n: Node): void {
    this
      .print('  ')
      .quoted(n.id)
      .print(' [')
      .println('];');
  }

  // --- Edge
  edge(e: Edge): void {
    this
      .print('  ')
      .quoted(e.source)
      .print(' -> ')
      .quoted(e.target)
      .print(' [')
      .println('];');
  }
}

const byStr = (a: string, b: string): number => {
  if (a < b) return -1;
  if (a > b) return +1;
  return 0;
}

const byNode = (a: Node, b: Node): number => byStr(a.id, b.id);
const byEdge = (a: Edge, b: Edge): number => byStr(edgeKey(a), edgeKey(b));

/* -------------------------------------------------------------------------- */
/* --- d3-Graphviz Component                                              --- */
/* -------------------------------------------------------------------------- */

interface GraphvizProps extends DiagramProps { size: Size }

function Graphviz(props: GraphvizProps): JSX.Element {
  // --- Model Generation
  const { direction = 'LR', nodes, edges } = props;
  const model = React.useMemo(() => {
    const dot = new DotModel();
    dot.rankdir(direction);
    nodes.concat().sort(byNode).forEach(n => dot.node(n));
    edges.concat().sort(byEdge).forEach(e => dot.edge(e));
    return dot.flush();
  }, [nodes, edges]);
  // --- Model Update Callback
  const { onModelChanged } = props;
  React.useEffect(() => {
    if (onModelChanged) onModelChanged(model);
  }, [model, onModelChanged]);
  // --- Rendering
  return (
    <div style={props.size}>
      <pre style={{background: 'red'}}>
        {model}
      </pre>
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Dome Diagram Component                                             --- */
/* -------------------------------------------------------------------------- */

export function Diagram(props: DiagramProps): JSX.Element {
  const { display = true } = props;
  return (
    <>
      {display && (
        <AutoSizer>
          {(size: Size) => (
            <div className={props.className}>
              <Graphviz size={size} {...props} />
            </div>
          )}
        </AutoSizer>
      )}
    </>
  );
}

/* -------------------------------------------------------------------------- */
