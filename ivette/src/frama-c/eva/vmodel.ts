// --------------------------------------------------------------------------
// --- Eva Values
// --------------------------------------------------------------------------

// External Libs
import { throttle } from 'lodash';
import equal from 'react-fast-compare';

// Frama-C
import * as Server from 'frama-c/server';

// Plugins
import * as Values from 'frama-c/api/plugins/eva/values';

/* --------------------------------------------------------------------------*/
/* --- Utilities                                                          ---*/
/* --------------------------------------------------------------------------*/

export type callback = () => void;

export interface StateCallbacks {
  forceUpdate: callback;
  forceLayout: callback;
}

/* --------------------------------------------------------------------------*/
/* --- Cell Properties                                                    ---*/
/* --------------------------------------------------------------------------*/

export interface Size { cols: number; rows: number }

const LABEL = 12; /* number of chars for labels */
const EMPTY = { cols: 0, rows: 0 };

export function sizeof(text?: string): Size {
  if (!text) return EMPTY;
  const lines = text.split('\n');
  return {
    rows: lines.length,
    cols: lines.reduce((w, l) => Math.max(w, l.length), 0),
  };
}

export function merge(a: Size, b: Size): Size {
  return {
    cols: Math.max(a.cols, b.cols),
    rows: Math.max(a.rows, b.rows),
  };
}

export function addH(a: Size, b: Size, padding = 0): Size {
  return {
    cols: a.cols + b.cols + padding,
    rows: Math.max(a.rows, b.rows),
  };
}

export function addV(a: Size, b: Size, padding = 0): Size {
  return {
    cols: Math.max(a.cols, b.cols),
    rows: a.rows + b.rows + padding,
  };
}

/* --------------------------------------------------------------------------*/
/* --- Row Properties                                                     ---*/
/* --------------------------------------------------------------------------*/

export type RowKind = 'probes' | 'values' | 'callstack';

export interface Row {
  key: string;
  kind: RowKind;
  probes: Probe[];
  height: number;
}

/* --------------------------------------------------------------------------*/
/* --- Probe Labelling                                                    ---*/
/* --------------------------------------------------------------------------*/

const Ka = 'A'.charCodeAt(0);
const Kz = 'Z'.charCodeAt(0);
const LabelRing: string[] = [];
let La = Ka;
let Lk = 0;

function newLabel() {
  let lbl = LabelRing.shift();
  if (lbl) return lbl;
  const a = La;
  const k = Lk;
  lbl = String.fromCharCode(a);
  if (a < Kz) {
    La++;
  } else {
    La = Ka;
    Lk++;
  }
  return k > 0 ? lbl + k : lbl;
}

/* --------------------------------------------------------------------------*/
/* --- Probe State                                                        ---*/
/* --------------------------------------------------------------------------*/

export class Probe {

  // properties
  readonly marker: string;
  readonly state: StateCallbacks;
  transient = true;
  label?: string;
  code?: string;
  stmt?: string;
  rank?: number;
  layout: Size;
  summary: Size;

  constructor(state: StateCallbacks, marker: string) {
    this.marker = marker;
    this.state = state;
    this.layout = EMPTY;
    this.summary = EMPTY;
    this.requestProbeInfo = this.requestProbeInfo.bind(this);
    this.setPersistent = this.setPersistent.bind(this);
    this.setTransient = this.setTransient.bind(this);
  }

  requestProbeInfo() {
    Server
      .send(Values.getProbeInfo, this.marker)
      .then(({ code, stmt, rank }) => {
        this.code = code;
        this.stmt = stmt;
        this.rank = rank;
      })
      .catch(() => {
        this.code = '(error)';
      })
      .finally(this.state.forceUpdate);
  }

  setPersistent() {
    if (this.transient && this.code) {
      this.transient = false;
      if (this.code.length > LABEL)
        this.label = newLabel();
      this.state.forceLayout();
    }
  }

  setTransient() {
    if (!this.transient) {
      this.transient = true;
      if (this.label) {
        LabelRing.push(this.label);
        this.label = undefined;
      }
      this.state.forceLayout();
    }
  }

  static order(p: Probe, q: Probe): number {
    const rp = p.rank ?? 0;
    const rq = q.rank ?? 0;
    if (rp < rq) return (-1);
    if (rp > rq) return (+1);
    if (p.transient && !q.transient) return (-1);
    if (!p.transient && q.transient) return (+1);
    if (p.marker < q.marker) return (-1);
    if (p.marker > q.marker) return (+1);
    return 0;
  }

}

/* --------------------------------------------------------------------------*/
/* --- StmtCallstacks                                                     ---*/
/* --------------------------------------------------------------------------*/

export class StmtCallstacks {
  state: StateCallbacks;
  stmt: string;

  constructor(state: StateCallbacks, stmt: string) {
    this.state = state;
    this.stmt = stmt;
  }

}

/* --------------------------------------------------------------------------*/
/* --- Layout Algorithm                                                   ---*/
/* --------------------------------------------------------------------------*/

export interface LayoutProps {
  zoom?: number;
  margin: number;
}

class LayoutEngine {

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
/* --- Values State                                                       ---*/
/* --------------------------------------------------------------------------*/

export class VState implements StateCallbacks {

  constructor(forceUpdate: callback) {
    this.forceUpdate = forceUpdate;
    this.forceLayout = this.forceLayout.bind(this);
    this.forceReload = this.forceReload.bind(this);
    this.computeLayout = this.computeLayout.bind(this);
    this.setLayout = throttle(this.setLayout.bind(this), 300);
    this.getRowKey = this.getRowKey.bind(this);
    this.getRowCount = this.getRowCount.bind(this);
    this.getRowHeight = this.getRowHeight.bind(this);
  }

  // --- Probes
  private focused?: Probe;
  private remanent?: Probe; // last transient
  private probes = new Map<string, Probe>();

  getProbe(m: string): Probe {
    let p = this.probes.get(m);
    if (!p) {
      p = new Probe(this, m);
      this.probes.set(m, p);
      p.requestProbeInfo();
    }
    return p;
  }

  focus(m: string | undefined): Probe | undefined {
    const r = this.remanent;
    if (m) {
      const p = this.getProbe(m);
      if (p.stmt) {
        this.focused = p;
        if (p.transient && p !== r) {
          this.remanent = p;
          this.forceLayout();
        }
      } else {
        this.focused = undefined;
        this.remanent = undefined;
        this.forceLayout();
      }
    }
    return this.focused;
  }

  // --- Rows

  private forcedLayout = false;
  private layout: LayoutProps = { margin: 80 };
  private rows: Row[] = [];

  forceLayout() {
    if (!this.forcedLayout) {
      this.forcedLayout = true;
      setImmediate(this.computeLayout);
    }
  }

  private computeLayout() {
    this.forcedLayout = false;
    const toLayout: Probe[] = [];
    this.probes.forEach((p) => {
      if (p.code && (!p.transient || p === this.remanent)) {
        toLayout.push(p);
      }
    });
    const engine = new LayoutEngine(this.layout);
    toLayout.sort(Probe.order).forEach(engine.push);
    this.rows = engine.flush();
    this.forceUpdate();
  }

  getRow(index: number): Row | undefined {
    return this.rows[index];
  }

  getRowCount() {
    return this.rows.length;
  }

  getRowKey(index: number): string {
    const row = this.rows[index];
    return row ? row.key : `#${index}`;
  }

  getRowHeight(index: number): number {
    const row = this.rows[index];
    return row ? row.height : 0;
  }

  // --- Throttled
  setLayout(ly: LayoutProps, forceGridLayout: callback) {
    if (!equal(this.layout, ly)) {
      this.layout = ly;
      this.forceLayout();
      forceGridLayout();
    }
  }

  // --- Force Reload (empty caches)
  forceReload() {
    this.probes.forEach((p) => {
      if (p.transient && p !== this.focused) {
        this.probes.delete(p.marker);
      } else {
        p.requestProbeInfo();
      }
    });

  }

  // --- Force Updating (re-render)
  private signal?: callback;

  bind(age: number, setAge: (a: number) => void) {
    const next = age < 0xFFFF ? 1 + age : 0;
    this.signal = () => setAge(next);
    return () => { this.signal = undefined; };
  }

  forceUpdate() {
    const s = this.signal;
    if (s) { this.signal = undefined; s(); }
  }

}

// --------------------------------------------------------------------------
