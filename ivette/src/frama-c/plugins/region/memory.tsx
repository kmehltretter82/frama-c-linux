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

// --------------------------------------------------------------------------
// --- Regions
// --------------------------------------------------------------------------

import React from 'react';
import * as Dot from 'dome/graph/diagram';
import * as Region from './api';

function makeRecord(
  edges: Dot.Edge[],
  source: string,
  sizeof: number,
  ranges: Region.range[]
): Dot.Cell[] {
  if (ranges.length === 0) return [];
  const cells: Dot.Cell[] = [];
  let offset = 0;
  ranges.forEach((rg, i) => {
    const port = `r${i}`;
    const target = `n${rg.data}`;
    edges.push({
      source, sourcePort: port, target,
      head: 'none', line: 'dashed'
    });
    if (offset !== rg.offset)
      cells.push(`${offset}..${rg.offset - 1} ##`);
    offset = rg.offset + rg.length;
    cells.push({
      label: `${rg.offset}..${offset - 1} [${rg.cells}]`,
      port,
    });
  });
  if (offset !== sizeof)
    cells.push(`${offset}..${sizeof - 1} ##`);
  return cells;
}

interface Diagram {
  nodes: Dot.Node[];
  edges: Dot.Edge[];
}

function makeDiagram(regions: readonly Region.region[]): Diagram {
  const nodes: Dot.Node[] = [];
  const edges: Dot.Edge[] = [];
  regions.forEach(r => {
    const id = `n${r.node}`;
    // --- Color
    const color =
      r.bytes ? 'red' :
        r.pointed !== undefined
          ? (r.writes ? 'orange' : 'yellow')
          : (r.writes && r.reads) ? 'green' :
            r.writes ? 'pink' : r.reads ? 'grey' : 'white';
    // --- Shape
    const font = r.ranges.length > 0 ? 'mono' : 'sans';
    const cells = makeRecord(edges, id, r.sizeof, r.ranges);
    const shape = cells.length > 0 ? cells : undefined;
    nodes.push({ id, font, color, label: r.label, title: r.title, shape });
    // --- Labels
    const L: Dot.Node =
      { id: '', shape: 'note', font: 'mono' };
    r.labels.forEach(a => {
      const lid = `L${a}`;
      nodes.push({ ...L, id: lid, label: `${a}:` });
      edges.push({
        source: lid, target: id, aligned: true,
        headAnchor: 'n', head: 'none', color: 'grey'
      });
    });
    // --- Roots
    const R: Dot.Node =
      { id: '', shape: 'cds', font: 'mono' };
    r.roots.forEach(x => {
      const xid = `X${x}`;
      nodes.push({ ...R, id: xid, label: x });
      edges.push({
        source: xid, target: id,
        headAnchor: "e", head: 'none', color: 'grey'
      });
    });
    // --- Pointed
    if (r.pointed !== undefined) {
      const pid = `n${r.pointed}`;
      edges.push({ source: id, target: pid });
    }
  });
  return { nodes, edges };
}

function addSelected(d: Diagram, label: string, node: Region.node): void {
  d.nodes.push({
    id: 'Selected', label, title: "Selected Marker", shape: 'note'
  });
  d.edges.push({ source: 'Selected', target: `n${node}` });
}

export interface MemoryViewProps {
  regions?: readonly Region.region[];
  node?: Region.node | undefined;
  label?: string;
}

export function MemoryView(props: MemoryViewProps): JSX.Element {
  const { regions = [], label, node } = props;
  const diagram = React.useMemo(() => makeDiagram(regions), [regions]);
  if (label && node) addSelected(diagram, label, node);
  return <Dot.Diagram {...diagram} />;
}

// --------------------------------------------------------------------------
