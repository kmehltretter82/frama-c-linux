/* --------------------------------------------------------------------------*/
/* --- Layout                                                             ---*/
/* --------------------------------------------------------------------------*/

import { Size, EMPTY, addH, ValueCache } from './cells';
import { Probe } from './probes';

export interface LayoutProps {
  zoom?: number;
  margin: number;
}

export type RowKind = 'probes' | 'values' | 'callstack';

export interface Row {
  key: string;
  kind: RowKind;
  probes: Probe[];
  height: number;
}

/* --------------------------------------------------------------------------*/
/* --- Layout Enfine                                                      ---*/
/* --------------------------------------------------------------------------*/

const PADDING = 2;
const HCROP = 18;
const VCROP = 1;

export class LayoutEngine {

  // --- Setup

  private readonly cache: ValueCache;
  private readonly hcrop: number;
  private readonly vcrop: number;
  private readonly margin: number;

  constructor(
    cache: ValueCache,
    props: undefined | LayoutProps,
  ) {
    this.cache = cache;
    const zoom = Math.max(0, props?.zoom ?? 0);
    this.vcrop = VCROP + 2 * zoom;
    this.hcrop = HCROP + zoom;
    this.margin = props?.margin ?? 80;
    this.push = this.push.bind(this);
  }

  // --- Probe Buffer
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
    const probeSize = this.cache.getProbeSize(p.marker);
    const s = this.crop(probeSize);
    p.minCols = s.cols;
    p.maxCols = Math.max(p.minCols, probeSize.cols);
    if (s.cols + this.rowSize.cols > this.margin) this.flush();
    this.rowSize = addH(this.rowSize, s);
    this.rowSize.cols += PADDING;
    this.buffer.push(p);
  }

  // --- Flush Buffer
  flush(): Row[] {
    const ps = this.buffer;
    const rs = this.rows;
    if (ps.length > 0) {
      const n = rs.length;
      rs.push({
        key: `P${n}`,
        kind: 'probes',
        probes: ps,
        height: 1,
      }, {
        key: `V${n}`,
        kind: 'values',
        probes: ps,
        height: this.rowSize.rows,
      });
    }
    this.buffer = [];
    this.rowSize = EMPTY;
    return rs;
  }

}

/* --------------------------------------------------------------------------*/
