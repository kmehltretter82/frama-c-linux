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
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import { Size } from 'react-virtualized';
import { select, selectAll } from 'd3-selection';
import { graphviz } from 'd3-graphviz';
import AutoSizer from 'react-virtualized-auto-sizer';
import './style.css';

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export type Direction = 'LR' | 'TD';

export type Color =
  | 'white' | 'grey' | 'dark'
  | 'primary' | 'selected'
  | 'green' | 'orange' | 'red'
  | 'yellow' | 'blue' | 'pink';

export type Shape =
  | 'point' | 'box'
  | 'diamond' | 'hexagon'
  | 'circle' | 'ellipse'
  | 'note' | 'tab' | 'folder';

export type Arrow = 'none' | 'arrow' | 'tee' | 'box' | 'dot';

export type Line = 'solid' | 'dashed' | 'dotted';

export type Cell = string | { label: string, port: string };

export type Box = Cell | Box[];

export interface Node {
  /** Node identifier (unique). */
  id: string;
  /** Node label */
  label?: string;
  /** Node tooltip */
  title?: string;
  /** Node color (filled background) */
  color?: Color;
  /**
   * Shape. Nested boxes alternate LR and TD directions. Initial direction is
   * orthogonal to the graph direction. Node label is ignored for box layout.
   */
  shape?: Shape | Box[];
}

/**
 *  Edge properties.
 *  Alternative syntax `id:port` is also supported for port names.
 */
export interface Edge {
  /** Source node identifier */
  source: string;
  /** Source port (provided source node has box shape) */
  sourcePort?: string;
  /** Target node identifier */
  target: string;
  /** Target port (provided target node has box shape) */
  targetPort?: string;
  /** Default is `solid` */
  line?: Line;
  /** Default is `dark` */
  color?: Color;
  /** Default is `arrow` */
  head?: Arrow;
  /** Default is `none` */
  tail?: Arrow;
  /** Label */
  label?: string;
  /** Tooltip */
  title?: string;
  /** Head label */
  headLabel?: string,
  /** Tail label */
  tailLabel?: string,
}

/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface DiagramProps {
  nodes: readonly Node[];
  edges: readonly Edge[];

  /**
     Element to focus on.
     The default color for this element is `'selected'`.
   */
  selected?: string;

  /** Top-Down (`'TD'`, default) or Left-Right (`'LR'`) direction. */
  direction?: Direction;

  /** Invoked when a node is selected. */
  onSelection?: (node: string | undefined) => void;

  /** Whether the Graph shall be displayed or not (defaults to true). */
  display?: boolean;

  /** Styling the Graph main div element. */
  className?: string;

  /** Debug the generated DotModel */
  onModelChanged?: (model: string) => void;

}

/* -------------------------------------------------------------------------- */
/* --- Color Model                                                        --- */
/* -------------------------------------------------------------------------- */

const BGCOLOR = {
  'white': '#fff',
  'grey': '#ccc',
  'dark': '#666',
  'primary': 'dodgerblue',
  'selected': 'deepskyblue',
  'green': 'lime',
  'orange': '#ffa700',
  'red': 'red',
  'yellow': 'yellow',
  'blue': 'cyan',
  'pink': 'hotpink',
};

const FGCOLOR = {
  'white': 'black',
  'grey': 'black',
  'dark': 'white',
  'primary': 'white',
  'selected': 'black',
  'green': 'black',
  'orange': 'black',
  'red': 'white',
  'yellow': 'black',
  'blue': 'black',
  'pink': 'white',
};

const EDCOLOR = {
  'white': '#ccc',
  'grey': '#888',
  'dark': 'black',
  'primary': 'dodgerblue',
  'selected': 'deepskyblue',
  'green': 'green',
  'orange': 'orange',
  'red': 'red',
  'yellow': '#e5e100',
  'blue': 'deepskyblue',
  'pink': 'palevioletred1',
};

/* -------------------------------------------------------------------------- */
/* --- Edge Model                                                         --- */
/* -------------------------------------------------------------------------- */

const DIR = (h: Arrow, t: Arrow): string | undefined =>
  h === 'none'
    ? (t === 'none' ? 'none' : 'back')
    : (t === 'none' ? undefined : 'both');

/* -------------------------------------------------------------------------- */
/* --- Dot Model                                                          --- */
/* -------------------------------------------------------------------------- */

type edgeSpec = { source: string, target: string };
const edgeKey = (e: edgeSpec): string => `${e.source} -> ${e.target}`;

class DotModel {
  private selected: string | undefined;
  private spec = 'digraph {\n';

  constructor(s: string | undefined) { this.selected = s; }

  print(...text: string[]): DotModel {
    this.spec = this.spec.concat(...text);
    return this;
  }

  println(...text: string[]): DotModel {
    this.spec = this.spec.concat(...text).concat('\n');
    return this;
  }

  flush(): string { return this.spec.concat('}'); }

  // --- Attributes
  value(a: string | number): DotModel {
    if (typeof a === 'string')
      return this.print('"', a, '"');
    else
      return this.print(`${a}`);
  }

  attr(a: string, v: string | number | undefined): DotModel {
    return v ? this.print(' ', a, '=').value(v).print('; ') : this;
  }

  // --- Node Table Shape

  port(id: string, port?: string): DotModel {
    this.print(id);
    if (port) this.print(':', port);
    return this;
  }

  record(r: Box, nested = false): DotModel {
    if (Array.isArray(r)) {
      if (nested) this.print('{');
      r.forEach((c, k) => {
        if (k > 0) this.print('|');
        this.record(c, true);
      });
      if (nested) this.print('}');
      return this;
    } else if (typeof r === 'string') {
      return this.print(r);
    } else {
      return this.print('<', r.port, '> ', r.label);
    }
  }

  // --- Node
  node(n: Node): void {
    this.print('  ', n.id, ' [');
    if (typeof n.shape === 'object') {
      this
        .attr('shape', 'record')
        .print(' label="').record(n.shape).print('"; ');
    } else {
      this
        .attr('label', n.label)
        .attr('shape', n.shape);
    }
    const color = n.color ?? (n.id === this.selected ? 'selected' : 'white');
    this
      .attr('id', n.id)
      .attr('tooltip', n.title)
      .attr('fontcolor', FGCOLOR[color])
      .attr('fillcolor', BGCOLOR[color])
      .println('];');
  }

  // --- Edge
  edge(e: Edge): void {
    const { line = 'solid', head = 'arrow', tail = 'none' } = e;
    this
      .print('  ')
      .port(e.source, e.sourcePort)
      .print(' -> ')
      .port(e.target, e.targetPort)
      .print(' [')
      .attr('label', e.label)
      .attr('headlabel', e.headLabel)
      .attr('taillabel', e.tailLabel)
      .attr('labeltooltip', e.title)
      .attr('dir', DIR(head, tail))
      .attr('color', e.color ? EDCOLOR[e.color] : undefined)
      .attr('style', line === 'solid' ? undefined : line)
      .attr('arrowhead', head === 'arrow' ? undefined : head)
      .attr('arrowtail', tail === 'arrow' ? undefined : tail)
      .println('];');
  }
}

const byStr = (a: string, b: string): number => {
  if (a < b) return -1;
  if (a > b) return +1;
  return 0;
};

const byNode = (a: Node, b: Node): number => byStr(a.id, b.id);
const byEdge = (a: Edge, b: Edge): number => byStr(edgeKey(a), edgeKey(b));

/* -------------------------------------------------------------------------- */
/* --- d3-Graphviz view                                                   --- */
/* -------------------------------------------------------------------------- */

let divId = 0;
const newDivId = (): string => `dome_xDiagram_g${++divId}`;

interface GraphvizProps extends DiagramProps { size: Size }

function GraphvizView(props: GraphvizProps): JSX.Element {

  // --- Model Generation
  const { direction = 'LR', nodes, edges, selected } = props;
  const model = React.useMemo(() => {
    const dot = new DotModel(selected);
    dot
      .attr('rankdir', direction)
      .attr('bgcolor', 'none')
      .attr('width', 0.5)
      .println('node [ style="filled" ];');
    nodes.concat().sort(byNode).forEach(n => dot.node(n));
    edges.concat().sort(byEdge).forEach(e => dot.edge(e));
    return dot.flush();
  }, [direction, nodes, edges, selected]);

  // --- Model Update Callback
  const { onModelChanged } = props;
  React.useEffect(() => {
    if (onModelChanged) onModelChanged(model);
  }, [model, onModelChanged]);


  // --- Rendering & Remote
  const id = React.useMemo(newDivId, []);
  const href = `#${id}`;
  const { onSelection } = props;
  const { width, height } = props.size;
  React.useEffect(() => {
    graphviz(href, {
      useWorker: false,
      fit: true, zoom: true, width, height,
    }).renderDot(model).on('end', function () {
      if (onSelection) {
        selectAll('.node')
          .on('click', function (evt: PointerEvent) {
            const s = select(this).attr('id');
            if (s) {
              evt.stopPropagation();
              onSelection(s);
            }
          });
      }
    });
  }, [href, model, width, height, onSelection]);

  const onClick = React.useCallback((): void => {
    if (onSelection) onSelection(undefined);
  }, [onSelection]);

  const onKey = React.useCallback((evt: React.KeyboardEvent): void => {
    if (evt.key === 'Escape') {
      evt.preventDefault();
      graphviz(href).resetZoom();
      if (onSelection) onSelection(undefined);
    }
  }, [href, onSelection]);

  return (
    <Catch label='Graphviz Error'>
      <div
        id={id}
        tabIndex={-1}
        style={{ outline: 'none' }}
        className={props.className}
        onKeyDown={onKey}
        onClick={onClick} />
    </Catch>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Dome Diagram Component                                             --- */
/* -------------------------------------------------------------------------- */

export function Diagram(props: DiagramProps): JSX.Element {
  const { display = true } = props;
  const className = classes('dome-xDiagram', props.className);
  return (
    <>
      {display && (
        <AutoSizer>
          {(size: Size) => (
            <div className={className} style={size}>
              <GraphvizView size={size} {...props} />
            </div>
          )}
        </AutoSizer>
      )}
    </>
  );
}

/* -------------------------------------------------------------------------- */
