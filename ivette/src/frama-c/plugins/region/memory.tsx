/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
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
      cells.push(`#${rg.offset - offset}b`);
    offset = rg.offset + rg.length;
    const label = rg.label;
    cells.push({ label, port });
  });
  if (offset !== sizeof)
    cells.push(`#${sizeof - offset}b`);
  return cells;
}

interface Diagram {
  nodes: readonly Dot.Node[];
  edges: readonly Dot.Edge[];
}

function makeDiagram(regions: readonly Region.region[]): Diagram {
  const nodes: Dot.Node[] = [];
  const edges: Dot.Edge[] = [];
  regions.forEach(r => {
    const id = `n${r.node}`;
    // --- Color
    const rd = r.reads.length > 0;
    const wr = r.writes.length > 0;
    const color =
      (!wr && !rd) ? undefined :
        !r.typed ? 'red' :
          r.pointed !== undefined
            ? (wr ? 'orange' : 'yellow')
            : (wr && rd) ? 'green' :
              wr ? 'pink' : 'grey';
    // --- Shape
    const font = r.ranges.length > 0 ? 'mono' : 'sans';
    const cells = makeRecord(edges, id, r.sizeof, r.ranges);
    const shape = cells.length > 0 ? cells : undefined;
    nodes.push({ id, font, color, label: r.label, title: r.title, shape });
    // --- Labels
    const L: Dot.Node = { id: '', shape: 'note', font: 'mono' };
    r.labels.forEach(a => {
      const lid = `L${a}`;
      nodes.push({ ...L, id: lid, label: `${a}:` });
      edges.push({
        source: lid, target: id, aligned: true,
        headAnchor: 's', head: 'none', color: 'grey'
      });
    });
    // --- Roots
    const R: Dot.Node = { id: '', shape: 'cds', font: 'mono' };
    // --- Roots: Result
    if (r.result) {
      const rid = '\\result';
      nodes.push({ ...R, id: rid, label: rid, title: "Returned value" });
      edges.push({
        source: rid, target: id,
        headAnchor: "e", head: 'none', color: 'grey'
      });
    }
    // --- Roots: Variables
    r.cvars.forEach(r => {
      const xid = `X${r.name}`;
      nodes.push({ ...R, id: xid, label: r.label, title: r.title });
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

function addSelected(
  diag: Diagram,
  node: Region.node | undefined,
  label: string | undefined
): Diagram {
  if (node && label) {
    const nodes = diag.nodes.concat({
      id: 'Selected', label, title: "Selected Marker",
      shape: 'note', color: 'selected'
    });
    const edges = diag.edges.concat({
      source: 'Selected', target: `n${node}`, aligned: true,
      headAnchor: 's', tailAnchor: 'n',
    });
    return { nodes, edges };
  } else
    return diag;
}

export interface MemoryViewProps {
  regions?: readonly Region.region[];
  node?: Region.node | undefined;
  label?: string;
}

export function MemoryView(props: MemoryViewProps): JSX.Element {
  const { regions = [], label, node } = props;
  const baseDiagram = React.useMemo(() => makeDiagram(regions), [regions]);
  const fullDiagram = React.useMemo(
    () => addSelected(baseDiagram, node, label),
    [baseDiagram, node, label]
  );
  return <Dot.Diagram {...fullDiagram} />;
}

// --------------------------------------------------------------------------
