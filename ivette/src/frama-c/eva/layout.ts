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

export type RowKind = 'probes' | 'values' | 'callstack';

export interface Row {
  key: string;
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

const PADDING = 2;
const INSET = 1;
const HCROP = 18;
const VCROP = 1;

export class LayoutEngine {

  // --- Setup

  private readonly values: ValueCache;
  private readonly stacks: StacksCache;
  private readonly hcrop: number;
  private readonly vcrop: number;
  private readonly margin: number;

  constructor(
    props: undefined | LayoutProps,
    values: ValueCache,
    stacks: StacksCache,
  ) {
    this.values = values;
    this.stacks = stacks;
    const zoom = Math.max(0, props?.zoom ?? 0);
    this.vcrop = VCROP + 3 * zoom;
    this.hcrop = HCROP + zoom;
    this.margin = props?.margin ?? 80;
    this.push = this.push.bind(this);
  }

  // --- Probe Buffer
  private byFctStacks?: string; // function
  private rowSize: Size = EMPTY;
  private buffer: Probe[] = [];
  private rows: Row[] = [];
  private chained?: Probe;

  crop(zoomed: boolean, s: Size): Size {
    const s$cols = s.cols + INSET;
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
    const q = this.chained;
    if (q) q.next = p;
    p.prev = q;
    this.chained = p;
    const probeSize = this.values.getProbeSize(p.marker);
    const s = this.crop(p.zoomed, probeSize);
    p.zoomable = p.zoomed || !leq(probeSize, s);
    p.minCols = s.cols;
    p.maxCols = Math.max(p.minCols, probeSize.cols);
    const fct = p.byCallstacks ? p.fct : undefined;
    if (fct !== this.byFctStacks) {
      this.flush();
      this.byFctStacks = fct;
    }
    if (!fct && s.cols + this.rowSize.cols > this.margin)
      this.flush();
    this.rowSize = addH(this.rowSize, s);
    this.rowSize.cols += PADDING;
    this.buffer.push(p);
  }

  // --- Flush Rows

  private flush(): Row[] {
    const ps = this.buffer;
    const rs = this.rows;
    if (ps.length > 0) {
      const fct = this.byFctStacks;
      const hlines = this.rowSize.rows;
      if (fct) {
        // --- by callstacks
        const markers = ps.map((p) => p.marker);
        const stacks = this.stacks.getStacks(...markers);
        const summary = this.stacks.getSummary(fct);
        const callstacks = stacks.length;
        rs.push({
          key: `F:${fct}`,
          kind: 'probes',
          probes: ps,
          stackCount: callstacks,
          hlines: 1,
        });
        if (summary) rs.push({
          key: `M:${fct}`,
          kind: 'values',
          probes: ps,
          stackIndex: -1,
          stackCount: stacks.length,
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
            hlines,
          });
        });
      } else {
        // --- not by callstacks
        const n = rs.length;
        rs.push({
          key: `P${n}`,
          kind: 'probes',
          probes: ps,
          hlines: 1,
        }, {
          key: `V${n}`,
          kind: 'values',
          probes: ps,
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
