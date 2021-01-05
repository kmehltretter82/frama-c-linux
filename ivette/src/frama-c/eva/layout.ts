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
  stacks?: number;
  stackIndex?: number;
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
    this.vcrop = VCROP + 2 * zoom;
    this.hcrop = HCROP + zoom;
    this.margin = props?.margin ?? 80;
    this.push = this.push.bind(this);
  }

  // --- Probe Buffer
  private byFctStacks?: string; // function
  private rowSize: Size = EMPTY;
  private buffer: Probe[] = [];
  private rows: Row[] = [];

  crop(zoomed: boolean, s: Size): Size {
    const sCols = s.cols + INSET;
    const cols = zoomed ? sCols : Math.min(sCols, this.hcrop);
    const rows = zoomed ? s.rows : Math.min(s.rows, this.vcrop);
    return {
      cols: Math.max(HCROP, cols),
      rows: Math.max(VCROP, rows),
    };
  }

  layout(ps: Probe[]): Row[] {
    ps.sort(LayoutEngine.order).forEach(this.push);
    return this.flush();
  }

  private static order(p: Probe, q: Probe): number {
    const fp = p.fct;
    const fq = q.fct;
    if (fp < fq) return -1;
    if (fp > fq) return +1;
    const cp = p.byCallstacks;
    const cq = q.byCallstacks;
    if (!cp && cq) return (-1);
    if (cp && !cq) return (+1);
    return Probe.order(p, q);
  }

  private push(p: Probe) {
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
        const wcs = this.stacks.getStacksForFunction(fct, markers);
        rs.push({
          key: `F${fct}`,
          kind: 'probes',
          probes: ps,
          stacks: wcs.length,
          hlines: 1,
        });
        wcs.forEach((cs, k) => {
          rs.push({
            key: `C${fct}::${cs}`,
            kind: 'callstack',
            probes: ps,
            stackIndex: k,
            stacks: wcs.length,
            callstack: cs,
            hlines,
          });
        });
      } else {
        // --- by callstacks
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
