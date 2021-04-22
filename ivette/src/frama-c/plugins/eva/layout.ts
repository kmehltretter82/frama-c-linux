/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

/* --------------------------------------------------------------------------*/
/* --- Layout                                                             ---*/
/* --------------------------------------------------------------------------*/

import { callstack } from 'frama-c/api/plugins/eva/values';
import { Probe } from './probes';
import { StacksCache } from './stacks';
import { Size, EMPTY, leq, addH, ValueCache } from './cells';

export interface LayoutProps {
  zoom?: number;
  margin: number;
}

export type RowKind = 'section' | 'probes' | 'values' | 'callstack';

export interface Row {
  key: string;
  fct: string;
  kind: RowKind;
  probes: Probe[];
  headstack?: string;
  stackIndex?: number;
  stackCount?: number;
  callstack?: callstack;
  hlines: number;
}

/* --------------------------------------------------------------------------*/
/* --- Layout Enfine                                                      ---*/
/* --------------------------------------------------------------------------*/

const HEAD_PADDING = 4; // Left margin
const CELL_PADDING = 4; // Inter cell padding
const TEXT_PADDING = 2; // Intra cell padding
const HCROP = 18;
const VCROP = 1;

export class LayoutEngine {

  // --- Setup

  private readonly folded: (fct: string) => boolean;
  private readonly values: ValueCache;
  private readonly stacks: StacksCache;
  private readonly hcrop: number;
  private readonly vcrop: number;
  private readonly margin: number;

  constructor(
    props: undefined | LayoutProps,
    values: ValueCache,
    stacks: StacksCache,
    folded: (fct: string) => boolean,
  ) {
    this.values = values;
    this.stacks = stacks;
    this.folded = folded;
    const zoom = Math.max(0, props?.zoom ?? 0);
    this.vcrop = VCROP + 3 * zoom;
    this.hcrop = HCROP + zoom;
    this.margin = (props?.margin ?? 80) - HEAD_PADDING;
    this.push = this.push.bind(this);
  }

  // --- Probe Buffer
  private byFct?: string; // current function
  private byStk?: boolean; // callstack probes
  private skip?: boolean; // skip current function
  private rowSize: Size = EMPTY;
  private buffer: Probe[] = [];
  private rows: Row[] = [];
  private chained?: Probe;

  crop(zoomed: boolean, s: Size): Size {
    const s$cols = s.cols + TEXT_PADDING;
    const cols = zoomed ? s$cols : Math.min(s$cols, this.hcrop);
    const rows = zoomed ? s.rows : Math.min(s.rows, this.vcrop);
    return {
      cols: Math.max(HCROP, cols),
      rows: Math.max(VCROP, rows),
    };
  }

  layout(ps: Probe[]): Row[] {
    this.chained = undefined;
    ps.sort(LayoutEngine.order).forEach(this.push);
    return this.flush();
  }

  private static order(p: Probe, q: Probe): number {
    const fp = p.fct;
    const fq = q.fct;
    if (fp === fq) {
      const cp = p.byCallstacks;
      const cq = q.byCallstacks;
      if (!cp && cq) return (-1);
      if (cp && !cq) return (+1);
    }
    const rp = p.rank ?? 0;
    const rq = q.rank ?? 0;
    if (rp < rq) return (-1);
    if (rp > rq) return (+1);
    if (p.marker < q.marker) return (-1);
    if (p.marker > q.marker) return (+1);
    return 0;
  }

  private push(p: Probe) {
    // --- sectionning
    const { fct, byCallstacks: stk } = p;
    if (fct !== this.byFct) {
      this.flush();
      this.rows.push({
        key: `S:${fct}`,
        kind: 'section',
        fct,
        probes: [],
        hlines: 1,
      });
      this.byFct = fct;
      this.byStk = stk;
      this.skip = this.folded(fct);
    } else if (stk !== this.byStk) {
      this.flush();
      this.byStk = stk;
    }
    if (this.skip) return;
    // --- chaining
    const q = this.chained;
    if (q) q.next = p;
    p.prev = q;
    this.chained = p;
    // --- sizing
    const probeSize = this.values.getProbeSize(p.marker);
    const s = this.crop(p.zoomed, probeSize);
    p.zoomable = p.zoomed || !leq(probeSize, s);
    p.minCols = s.cols;
    p.maxCols = Math.max(p.minCols, probeSize.cols);
    // --- queueing
    if (!stk && s.cols + this.rowSize.cols > this.margin)
      this.flush();
    this.rowSize = addH(this.rowSize, s);
    this.rowSize.cols += CELL_PADDING;
    this.buffer.push(p);
  }

  // --- Flush Rows

  private flush(): Row[] {
    const ps = this.buffer;
    const rs = this.rows;
    const fct = this.byFct;
    if (fct && ps.length > 0) {
      const stk = this.byStk;
      const hlines = this.rowSize.rows;
      if (stk) {
        // --- by callstacks
        const markers = ps.map((p) => p.marker);
        const stacks = this.stacks.getStacks(...markers);
        const summary = fct ? this.stacks.getSummary(fct) : false;
        const callstacks = stacks.length;
        rs.push({
          key: `P:${fct}`,
          kind: 'probes',
          probes: ps,
          stackCount: callstacks,
          fct,
          hlines: 1,
        });
        if (summary) rs.push({
          key: `V:${fct}`,
          kind: 'values',
          probes: ps,
          stackIndex: -1,
          stackCount: stacks.length,
          fct,
          hlines: 1,
        });
        stacks.forEach((cs, k) => {
          rs.push({
            key: `C:${fct}:${cs}`,
            kind: 'callstack',
            probes: ps,
            stackIndex: k,
            stackCount: callstacks,
            callstack: cs,
            fct,
            hlines,
          });
        });
      } else {
        // --- not by callstacks
        const n = rs.length;
        rs.push({
          key: `P#${n}`,
          kind: 'probes',
          probes: ps,
          fct,
          hlines: 1,
        }, {
          key: `V#${n}`,
          kind: 'values',
          probes: ps,
          fct,
          hlines,
        });
      }
    }
    this.buffer = [];
    this.rowSize = EMPTY;
    return rs;
  }

}

/* --------------------------------------------------------------------------*/
