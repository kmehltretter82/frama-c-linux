/* --------------------------------------------------------------------------*/
/* --- Layout                                                             ---*/
/* --------------------------------------------------------------------------*/

import { callstack } from 'frama-c/api/plugins/eva/values';
import { Probe } from './probes';
import { StacksCache } from './stacks';
import { Size, EMPTY, addH, ValueCache } from './cells';

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
  private byStacks?: string; // stmt
  private rowSize: Size = EMPTY;
  private buffer: Probe[] = [];
  private rows: Row[] = [];

  crop(s: Size): Size {
    return {
      cols: Math.max(HCROP, Math.min(s.cols, this.hcrop)),
      rows: Math.max(VCROP, Math.min(s.rows, this.vcrop)),
    };
  }

  push(p: Probe) {
    const probeSize = this.values.getProbeSize(p.marker);
    const s = this.crop(probeSize);
    p.minCols = s.cols;
    p.maxCols = Math.max(p.minCols, probeSize.cols);
    const stmt = p.byCallstacks ? p.stmt : undefined;
    if (stmt !== this.byStacks) {
      this.flush();
      this.byStacks = stmt;
    }
    if (!stmt && s.cols + this.rowSize.cols > this.margin)
      this.flush();
    this.rowSize = addH(this.rowSize, s);
    this.rowSize.cols += PADDING;
    this.buffer.push(p);
  }

  // --- Flush Rows

  flush(): Row[] {
    const ps = this.buffer;
    const rs = this.rows;
    if (ps.length > 0) {
      const stmt = this.byStacks;
      if (stmt) {
        // --- by callstacks
        const wcs = this.stacks.getStacks(stmt);
        rs.push({
          key: `P${stmt}`,
          kind: 'probes',
          probes: ps,
          stacks: wcs.length,
          hlines: 1,
        });
        wcs.forEach((cs, k) => {
          rs.push({
            key: `C${cs}`,
            kind: 'callstack',
            probes: ps,
            stackIndex: k,
            stacks: wcs.length,
            callstack: cs,
            hlines: this.values.getStackSize(cs).rows,
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
          hlines: this.rowSize.rows,
        });
      }
    }
    this.buffer = [];
    this.rowSize = EMPTY;
    return rs;
  }

}

/* --------------------------------------------------------------------------*/
