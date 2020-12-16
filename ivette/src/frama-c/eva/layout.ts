/* --------------------------------------------------------------------------*/
/* --- Layout                                                             ---*/
/* --------------------------------------------------------------------------*/

import { Size, EMPTY, LABEL, addH } from './cells';
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

export class LayoutEngine {

  // --- Setup

  /* private */ readonly wcrop: number;
  /* private */ readonly hcrop: number;
  /* private */ readonly margin: number;
  /* private */ readonly remanent?: Probe;

  constructor(
    props: undefined | LayoutProps,
  ) {
    const zoom = Math.max(0, props?.zoom ?? 0);
    this.hcrop = 1 + zoom;
    this.wcrop = LABEL + 2 * zoom;
    this.margin = props?.margin ?? 80;
    this.push = this.push.bind(this);
  }

  // --- Probe Buffer
  private rowSize: Size = EMPTY;
  private buffer: Probe[] = [];
  private rows: Row[] = [];

  crop(s: Size): Size {
    return {
      cols: Math.max(LABEL, Math.min(s.cols, this.wcrop)),
      rows: Math.max(1, Math.min(s.rows, this.hcrop)),
    };
  }

  push(p: Probe) {
    const s = this.crop(p.summary);
    if (s.cols + this.rowSize.cols > this.margin) this.flush();
    p.layout = s;
    this.rowSize = addH(this.rowSize, s);
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
