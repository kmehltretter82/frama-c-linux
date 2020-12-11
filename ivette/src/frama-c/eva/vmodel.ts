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

const LABEL = 12; /* number of chars for labels */
const EMPTY = { width: 0, height: 0 };

export interface Size { width: number; height: number }

export function sizeof(text?: string): Size {
  if (!text) return EMPTY;
  const lines = text.split('\n');
  return {
    height: lines.length,
    width: lines.reduce((w, l) => Math.max(w, l.length), 0),
  };
}

export function merge(a: Size, b: Size): Size {
  return {
    width: Math.max(a.width, b.width),
    height: Math.max(a.height, b.height),
  };
}

export function addH(a: Size, b: Size, padding = 0): Size {
  return {
    width: a.width + b.width + padding,
    height: Math.max(a.height, b.height),
  };
}

export function addV(a: Size, b: Size, padding = 0): Size {
  return {
    width: Math.max(a.width, b.width),
    height: a.height + b.height + padding,
  };
}

/* --------------------------------------------------------------------------*/
/* --- Row Properties                                                     ---*/
/* --------------------------------------------------------------------------*/

export type RowKind = 'probes' | 'values' | 'callstack';

export class Row {

  key: string;
  kind: RowKind;
  size: Size;
  height = 0;

  constructor(kind: RowKind, key: string) {
    this.key = key;
    this.kind = kind;
    this.size = EMPTY;
  }

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

export class Probe implements StateCallbacks {

  // properties
  readonly marker: string;
  forceUpdate: callback;
  forceLayout: callback;
  transient = true;
  label?: string;
  code?: string;
  stmt?: string;
  rank?: number;

  constructor(marker: string, state: StateCallbacks) {
    this.marker = marker;
    this.forceUpdate = state.forceUpdate;
    this.forceLayout = state.forceLayout;
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
      .finally(this.forceUpdate);
  }

  setPersistent() {
    if (this.transient && this.code) {
      this.transient = false;
      if (this.code.length > LABEL)
        this.label = newLabel();
      this.forceLayout();
    }
  }

  setTransient() {
    if (!this.transient) {
      this.transient = true;
      if (this.label) {
        LabelRing.push(this.label);
        this.label = undefined;
      }
      this.forceLayout();
    }
  }

}

/* --------------------------------------------------------------------------*/
/* --- Layout Algorithm                                                   ---*/
/* --------------------------------------------------------------------------*/

export interface LayoutProps {
  zoom?: number;
  wmax: number;
  hmax: number;
}

class LayoutEngine {

  // --- Setup

  /* private */ readonly wcrop: number;
  /* private */ readonly hcrop: number;
  /* private */ readonly wmax: number;
  /* private */ readonly hmax: number;
  /* private */ readonly remanent?: Probe;

  constructor(
    props: undefined | LayoutProps,
  ) {
    const zoom = Math.max(0, props?.zoom ?? 0);
    this.hcrop = zoom;
    this.wcrop = LABEL + 2 * zoom;
    this.wmax = props?.wmax ?? 80;
    this.hmax = props?.hmax ?? 60;
  }

  // --- Buffer

  private buffer?: Row;
  private readonly rows: Row[] = [];

  // --- Flushes current rows

  flush() {
    const p = this.buffer;
    if (p) {
      this.rows.push(p);
      this.buffer = undefined;
    }
    return this.rows;
  }

}

/* --------------------------------------------------------------------------*/
/* --- Values State                                                       ---*/
/* --------------------------------------------------------------------------*/

export class VState implements StateCallbacks {

  constructor() {
    this.forceUpdate = this.forceUpdate.bind(this);
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
      p = new Probe(m, this);
      this.probes.set(m, p);
      p.requestProbeInfo();
    }
    return p;
  }

  focus(m: string | undefined): Probe | undefined {
    if (m) {
      const p = this.getProbe(m);
      if (p.stmt) {
        this.focused = p;
        if (p.transient) this.remanent = p;
      } else {
        this.focused = undefined;
      }
    }
    return this.focused;
  }

  // --- Rows

  private forcedLayout = false;
  private layout?: LayoutProps;
  private rows: Row[] = [];

  forceLayout() {
    if (!this.forcedLayout) {
      this.forcedLayout = true;
      setImmediate(this.computeLayout);
    }
  }

  private computeLayout() {
    const probes: Probe[] = [];
    this.forcedLayout = false;
    this.probes.forEach((p) => {
      if (p.code || !p.transient || p === this.remanent) {
        probes.push(p);
      }
    });
    const engine = new LayoutEngine(this.layout);
    this.rows = engine.flush();
    this.forceUpdate();
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
  setLayout(ly?: LayoutProps) {
    if (!equal(this.layout, ly)) {
      this.layout = ly;
      this.forceLayout();
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
